import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/share/ayah_copy_text.dart';
import 'package:holyquran/ui/core/share/copy_sheet_view.dart';
import 'package:holyquran/ui/core/share/copy_sheet_view_model.dart';
import 'package:holyquran/ui/core/widgets/ayah_marker.dart';
import 'package:holyquran/ui/core/widgets/ayah_toolbar.dart';
import 'package:holyquran/ui/core/widgets/button.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';
import '../../testing/golden.dart';
import '../integrity/pack_integrity_suite.dart';
import '../ui/core/share/share_test_pack.dart';

// SH-01, SH-05, NF-20: what the user copies is the pack's text. Every ayah of
// the synthetic pack is copied through the app, from the sheet the router
// opens, and every ayah of a pack given with HOLYQURAN_PACK_DIR through the
// same sheet over that pack's repository. The clipboard is the platform's
// channel, which the test records. The format is read from the ARB file, so
// no template is typed here, and no copied text is ever printed.

final _templates =
    jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
        as Map<String, Object?>;

final _placeholder = RegExp(r'\{(\w+)\}');

/// The bytes of `copyFormatFull` filled with the stored [ayah] and [surah]
/// and the number [number] in Arabic-Indic digits.
List<int> _expected(List<int> ayah, List<int> surah, int number) {
  final template = _templates['copyFormatFull']! as String;
  final bytes = <int>[];
  var at = 0;
  for (final match in _placeholder.allMatches(template)) {
    bytes
      ..addAll(utf8.encode(template.substring(at, match.start)))
      ..addAll(switch (match[1]) {
        'ayah' => ayah,
        'surah' => surah,
        'number' => utf8.encode(arabicDigits(number)),
        final other => fail('copyFormatFull has the placeholder $other'),
      });
    at = match.end;
  }
  return bytes..addAll(utf8.encode(template.substring(at)));
}

/// Copies each of [ayat] with [copy], which opens the copy sheet and presses
/// «انسخ», and returns what differs from the stored text.
Future<List<String>> _copyAll(
  List<PackAyah> ayat,
  List<String> clipboard,
  Future<void> Function(QuranAddress ayah) copy,
) async {
  final problems = <String>[];
  for (final ayah in ayat) {
    final before = clipboard.length;
    await copy(ayah.address);
    if (clipboard.length != before + 1) {
      problems.add('${ayah.address}: ${clipboard.length - before} copies');
      continue;
    }
    final mismatch = byteMismatch(
      utf8.encode(clipboard.last),
      _expected(ayah.stored, ayah.storedName, ayah.address.ayah),
    );
    if (mismatch != null) problems.add('${ayah.address}: $mismatch');
  }
  return problems;
}

void main() {
  final rig = FlowRig();

  rig.test(
    'every ayah of the synthetic pack is copied, from the sheet of the app, '
    'as the pack stores it, and the toolbar leads to the same sheet',
    (tester, run) async {
      final clipboard = recordClipboard(tester);
      final pack = await real(
        tester,
        () => PackUnderTest.load(rig.bundle.path),
      );
      addTearDown(pack.close);
      final ayat = await real(
        tester,
        () => packAyat(pack, pack.openRepository()),
      );
      expect(ayat, hasLength(pack.manifest.counts.ayat));

      await run.session(tester, (session) async {
        final router = GoRouter.of(
          tester.element(find.byType(Navigator).first),
        );

        // The user's way to the sheet: the ayah, then «نسخ», then «انسخ».
        await tapNamed(tester, flowL10n.tabMushaf);
        final marker = find.byWidgetPredicate(
          (w) => w is AyahMarker && w.number == 3 && !w.playing,
        );
        await tester.tap(marker.first);
        await tester.pumpAndSettle();
        expect(find.byType(AyahToolbar), findsOneWidget);
        await tapNamed(tester, flowL10n.toolbarCopy);
        await tapNamed(
          tester,
          flowL10n.copyAction,
          done: () => clipboard.isNotEmpty,
        );
        final first = ayat.firstWhere(
          (a) => a.address.toString() == 'hafs:1:3',
        );
        expect(
          byteMismatch(
            utf8.encode(clipboard.single),
            _expected(first.stored, first.storedName, 3),
          ),
          isNull,
        );
        clipboard.clear();

        // Every ayah, through the sheet's route.
        final problems = await _copyAll(ayat, clipboard, (address) async {
          router.go(Routes.mushafRead(address));
          await tester.pumpAndSettle();
          unawaited(router.push<Object?>(Routes.copySheet(address)));
          await tester.pumpAndSettle();
          await tapNamed(
            tester,
            flowL10n.copyAction,
            done: () => clipboard.isNotEmpty,
          );
        });
        expectNoProblems(problems);
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  const given = givenPackDirectory;
  if (given.isEmpty) {
    test(
      'every ayah of the pack given with HOLYQURAN_PACK_DIR is copied as the '
      'pack stores it',
      () {},
      skip: 'no --dart-define=HOLYQURAN_PACK_DIR=<pack-id/version> was given',
    );
  } else {
    testWidgets(
      'every ayah of the pack HOLYQURAN_PACK_DIR=$given is copied as the '
      'pack stores it',
      (tester) async {
        tester.view
          ..physicalSize = const Size(390, 1200)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final clipboard = recordClipboard(tester);
        final pack = await real(tester, () => PackUnderTest.load(given));
        addTearDown(pack.close);
        final PackQuranTextRepository repository = pack.openRepository();
        final ayat = await real(tester, () => packAyat(pack, repository));
        expect(ayat, hasLength(pack.manifest.counts.ayat));
        final copyText = AyahCopyText(repository, flowL10n);

        final problems = await _copyAll(ayat, clipboard, (address) async {
          await tester.pumpWidget(
            goldenApp(
              ReadingTheme.paper,
              CopySheetView(
                key: ValueKey(address),
                create: () => CopySheetViewModel(
                  address: address,
                  copyText: copyText,
                  copyToClipboard: const SystemClipboardService().copyText,
                ),
              ),
            ),
          );
          await tester.pump();
          // The sheet sits in a plain page here, with no route to hit-test.
          tester
              .widget<Button>(find.widgetWithText(Button, flowL10n.copyAction))
              .onPressed!();
          await tester.pump();
        });
        expectNoProblems(problems);
      },
      timeout: const Timeout(Duration(minutes: 60)),
    );
  }
}
