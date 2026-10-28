import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/share/share_card_fit.dart';
import 'package:holyquran/ui/core/share/share_card_renderer.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';

import '../../../../testing/golden.dart';
import '../../../integrity/pack_integrity_suite.dart';
import 'share_test_pack.dart';

// SH-03 on the 50 shortest and the 50 longest ayat of the synthetic pack, and
// of a pack given with HOLYQURAN_PACK_DIR: each fit is the largest size the
// real card holds without overflow, the card draws the pack's bytes at it,
// and an ayah that fits nowhere is reported too long.

const _count = 50;

/// Pumps [card] and returns whether Flutter reported an overflow. A flex
/// reports its overflow once, so the card is built afresh.
Future<bool> _overflows(WidgetTester tester, ShareCard card) async {
  await tester.pumpWidget(goldenApp(ReadingTheme.paper, const SizedBox()));
  await tester.pumpWidget(goldenApp(ReadingTheme.paper, card));
  final error = tester.takeException();
  if (error == null) return false;
  expect(error, isA<FlutterError>());
  expect('$error', contains('overflowed'));
  return true;
}

ShareCard _card(PackAyah ayah, ShareCardDesign design, double fontSize) =>
    ShareCard(
      ayah: ayah.text,
      surahName: ayah.surahName,
      ayahNumber: ayah.address.ayah,
      ayahFontSize: fontSize,
      design: design,
    );

const _host = Key('host');

/// A renderer in the app the cards are pumped in.
Future<ShareCardRenderer> _renderer(WidgetTester tester) async {
  await tester.pumpWidget(
    goldenApp(ReadingTheme.paper, const SizedBox(key: _host)),
  );
  return ShareCardRenderer(tester.element(find.byKey(_host)));
}

void _fitsTheEnds(String description, Future<PackUnderTest> Function() load) {
  for (final design in ShareCardDesign.values) {
    testWidgets('$description, ${design.name}: the $_count shortest and '
        '$_count longest ayat fit as large as the card holds them', (
      tester,
    ) async {
      final pack = await tester.runAsync(load);
      final repository = pack!.openRepository();
      final ayat = shortestAndLongest(
        (await tester.runAsync(() => packAyat(pack, repository)))!,
        _count,
      );
      final problems = <String>[];
      var portrait = 0;
      var tall = 0;
      var tooLong = 0;
      for (final ayah in ayat) {
        final fits = (await _renderer(tester)).fitTest(_card(ayah, design, 22));
        final where = '${ayah.address} ${design.name}';
        switch (fitShareCard(ShareCardRatio.portrait, fits)) {
          case ShareCardFits(:final ratio, :final fontSize):
            if (ratio == ShareCardRatio.portrait) {
              portrait++;
              if (await _overflows(tester, _card(ayah, design, fontSize))) {
                problems.add('$where: overflows at $fontSize');
              }
              if (fontSize < shareCardFontSize &&
                  !await _overflows(
                    tester,
                    _card(ayah, design, fontSize + 1),
                  )) {
                problems.add('$where: ${fontSize + 1} fits as well');
              }
              await tester.pumpWidget(
                goldenApp(ReadingTheme.paper, _card(ayah, design, fontSize)),
              );
              final drawn = find.descendant(
                of: find.byType(QuranText),
                matching: find.byType(RichText),
              );
              problems.addAll(
                drawnTextProblems(
                  where,
                  tester.widget<RichText>(drawn).text,
                  tester.renderObject<RenderParagraph>(drawn).text,
                  ayah.stored,
                ),
              );
            } else {
              tall++;
              if (!await _overflows(tester, _card(ayah, design, 22))) {
                problems.add('$where: fits 4:5 at 22 but went tall');
              }
            }
          case ShareCardTooLong():
            tooLong++;
            if (!await _overflows(tester, _card(ayah, design, 22))) {
              problems.add('$where: fits 4:5 at 22 but is too long');
            }
            if (fits(ShareCardRatio.tall, 22)) {
              problems.add('$where: fits 9:16 at 22 but is too long');
            }
        }
      }
      expectNoProblems(problems);
      expect(portrait + tall + tooLong, ayat.length);
      if (description.startsWith('the synthetic')) {
        expect(portrait, greaterThan(0));
        expect(tall, greaterThan(0));
        expect(tooLong, greaterThan(0));
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

void main() {
  _fitsTheEnds('the synthetic pack', loadShareTestPack);

  if (givenPackDirectory.isEmpty) {
    test(
      'the pack given with HOLYQURAN_PACK_DIR',
      () {},
      skip: 'no --dart-define=HOLYQURAN_PACK_DIR=<pack-id/version> was given',
    );
  } else {
    _fitsTheEnds('the pack HOLYQURAN_PACK_DIR=$givenPackDirectory', () async {
      final pack = await PackUnderTest.load(givenPackDirectory);
      addTearDown(pack.close);
      return pack;
    });
  }

  testWidgets('the fit test agrees with the card at every size', (
    tester,
  ) async {
    final pack = (await tester.runAsync(loadShareTestPack))!;
    final repository = pack.openRepository();
    final ayat = (await tester.runAsync(() => packAyat(pack, repository)))!;
    final renderer = await _renderer(tester);
    // An ayah that 4:5 holds at 22 but not at 34, measured before any card
    // replaces the renderer's host.
    late PackAyah ayah;
    late Map<double, bool> fitted;
    for (final candidate in ayat) {
      final fits = renderer.fitTest(
        _card(candidate, ShareCardDesign.emerald, 22),
      );
      if (fits(ShareCardRatio.portrait, 22) &&
          !fits(ShareCardRatio.portrait, 34)) {
        ayah = candidate;
        fitted = {
          for (var size = 22.0; size <= 34; size++)
            size: fits(ShareCardRatio.portrait, size),
        };
        break;
      }
    }
    expect(fitted.values.toSet(), {true, false});
    final problems = <String>[];
    for (final MapEntry(key: size, value: fits) in fitted.entries) {
      final overflowed = await _overflows(
        tester,
        _card(ayah, ShareCardDesign.emerald, size),
      );
      if (fits == overflowed) problems.add('$size: fits $fits');
    }
    expectNoProblems(problems);
  });

  testWidgets('paints the card as a PNG 1080 pixels wide', (tester) async {
    final pack = (await tester.runAsync(loadShareTestPack))!;
    final repository = pack.openRepository();
    final ayah = (await tester.runAsync(
      () => packAyat(pack, repository),
    ))!.first;
    final card = _card(ayah, ShareCardDesign.paper, 34);
    final renderer = await _renderer(tester);
    final png = await tester.runAsync(() => renderer.png(card));
    if (png == null) fail('No image was painted.');
    final header = ByteData.sublistView(png);
    expect(png.sublist(1, 4), 'PNG'.codeUnits);
    expect(header.getUint32(16), 1080);
    expect(header.getUint32(20), 1350);
  });
}
