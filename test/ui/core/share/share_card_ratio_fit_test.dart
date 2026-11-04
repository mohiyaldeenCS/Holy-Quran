import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/share/share_card_fit.dart';
import 'package:holyquran/ui/core/share/share_card_renderer.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';

import '../../../../testing/golden.dart';
import '../../../integrity/pack_integrity_suite.dart';
import 'share_test_pack.dart';

// SH-03 and SH-02 at the three sizes, on synthetic ayat of increasing
// length: the fit rule from each starting size, checked against the real
// card at that size, and the exported image of each size.

const _host = Key('host');

ShareCard _card(
  PackAyah ayah,
  ShareCardDesign design,
  ShareCardRatio ratio,
  double fontSize,
) => ShareCard(
  ayah: ayah.text,
  surahName: ayah.surahName,
  ayahNumber: ayah.address.ayah,
  ayahFontSize: fontSize,
  design: design,
  ratio: ratio,
);

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

Future<ShareCardRenderer> _renderer(WidgetTester tester) async {
  await tester.pumpWidget(
    goldenApp(ReadingTheme.paper, const SizedBox(key: _host)),
  );
  return ShareCardRenderer(tester.element(find.byKey(_host)));
}

/// [count] ayat spread evenly over [ayat] by stored length, the shortest
/// and the longest among them.
List<PackAyah> _spread(List<PackAyah> ayat, int count) {
  final sorted = [...ayat]
    ..sort((a, b) => a.stored.length.compareTo(b.stored.length));
  return [
    for (var i = 0; i < count; i++)
      sorted[(i * (sorted.length - 1) / (count - 1)).round()],
  ];
}

/// Where a fit sits from the card's own size onwards: a larger number is a
/// longer ayah's.
int _rank(ShareCardFit fit) => switch (fit) {
  ShareCardFits(:final ratio, :final fontSize) =>
    ratio.index * 100 + (shareCardFontSize - fontSize).round(),
  ShareCardTooLong() => 1000,
};

void main() {
  for (final design in ShareCardDesign.values) {
    testWidgets('${design.name}: the fit from each size is the largest the '
        'real card holds, and never cuts the ayah', (tester) async {
      final pack = (await tester.runAsync(loadShareTestPack))!;
      final repository = pack.openRepository();
      final ayat = _spread(
        (await tester.runAsync(() => packAyat(pack, repository)))!,
        24,
      );
      final problems = <String>[];
      final seen = <ShareCardRatio, Set<Object>>{
        for (final ratio in ShareCardRatio.values) ratio: {},
      };
      for (final start in ShareCardRatio.values) {
        var previous = -1;
        for (final ayah in ayat) {
          final fits = (await _renderer(tester))
              .fitTest(_card(ayah, design, start, 22));
          final fit = fitShareCard(start, fits);
          final where = '${ayah.address} ${design.name} from ${start.name}';
          if (_rank(fit) < previous) {
            problems.add('$where: a longer ayah got a smaller card');
          }
          previous = _rank(fit);
          switch (fit) {
            case ShareCardFits(:final ratio, :final fontSize):
              seen[start]!.add(ratio);
              if (await _overflows(
                tester,
                _card(ayah, design, ratio, fontSize),
              )) {
                problems.add('$where: overflows at ${ratio.name} $fontSize');
              }
              if (fontSize < shareCardFontSize &&
                  !await _overflows(
                    tester,
                    _card(ayah, design, ratio, fontSize + 1),
                  )) {
                problems.add('$where: ${fontSize + 1} fits as well');
              }
              if (ratio != start &&
                  !await _overflows(tester, _card(ayah, design, start, 22))) {
                problems.add('$where: fits ${start.name} at 22 but moved');
              }
            case ShareCardTooLong():
              seen[start]!.add('too long');
              for (final ratio in {start, ShareCardRatio.tall}) {
                if (!await _overflows(tester, _card(ayah, design, ratio, 22))) {
                  problems.add('$where: fits ${ratio.name} at 22');
                }
              }
          }
        }
      }
      expectNoProblems(problems);
      for (final start in [ShareCardRatio.square, ShareCardRatio.portrait]) {
        expect(seen[start], {
          start,
          ShareCardRatio.tall,
          'too long',
        }, reason: 'from ${start.name}');
      }
      expect(seen[ShareCardRatio.tall], {ShareCardRatio.tall, 'too long'});
    }, timeout: const Timeout(Duration(minutes: 5)));
  }

  testWidgets('a taller card holds at least what a shorter one does', (
    tester,
  ) async {
    final pack = (await tester.runAsync(loadShareTestPack))!;
    final repository = pack.openRepository();
    final ayat = _spread(
      (await tester.runAsync(() => packAyat(pack, repository)))!,
      24,
    );
    final problems = <String>[];
    for (final ayah in ayat) {
      final fits = (await _renderer(
        tester,
      )).fitTest(_card(ayah, ShareCardDesign.emerald, ShareCardRatio.tall, 22));
      for (var size = 22.0; size <= shareCardFontSize; size++) {
        final held = [
          for (final ratio in ShareCardRatio.values) fits(ratio, size),
        ];
        if (held[0] && !held[1] || held[1] && !held[2]) {
          problems.add('${ayah.address} at $size: $held');
        }
      }
    }
    expectNoProblems(problems);
  });

  testWidgets('paints each size as a PNG 1080 pixels wide, as tall as its '
      'ratio gives', (tester) async {
    final pack = (await tester.runAsync(loadShareTestPack))!;
    final repository = pack.openRepository();
    final ayah = shortestAndLongest(
      (await tester.runAsync(() => packAyat(pack, repository)))!,
      1,
    ).first;
    final renderer = await _renderer(tester);
    for (final design in ShareCardDesign.values) {
      for (final (ratio, height) in [
        (ShareCardRatio.square, 1080),
        (ShareCardRatio.portrait, 1350),
        (ShareCardRatio.tall, 1920),
      ]) {
        final Uint8List? png = await tester.runAsync(
          () => renderer.png(_card(ayah, design, ratio, 34)),
        );
        if (png == null) fail('No image was painted.');
        final header = ByteData.sublistView(png);
        final where = '${design.name} ${ratio.name}';
        expect(png.sublist(1, 4), 'PNG'.codeUnits, reason: where);
        expect(header.getUint32(16), 1080, reason: where);
        expect(header.getUint32(20), height, reason: where);
      }
    }
  });
}
