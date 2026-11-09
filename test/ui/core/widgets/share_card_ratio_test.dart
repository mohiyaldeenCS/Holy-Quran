import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/share/share_card_fit.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

// Synthetic ayah and surah name.
const _text = PackText.fromPack('نص تجريبي');
const _name = PackText.fromPack('اسم تجريبي');

Future<void> _pump(
  WidgetTester tester,
  ShareCardDesign design,
  ShareCardRatio ratio,
) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
      ShareCard(
        ayah: _text,
        surahName: _name,
        ayahNumber: 5,
        ayahFontSize: 34,
        design: design,
        ratio: ratio,
      ),
    ),
  );
}

void main() {
  testWidgets('keeps the drawn width and takes its height from the ratio', (
    tester,
  ) async {
    for (final design in ShareCardDesign.values) {
      for (final (ratio, height) in [
        (ShareCardRatio.square, 300.0),
        (ShareCardRatio.portrait, 375.0),
        (ShareCardRatio.tall, 300 * 16 / 9),
      ]) {
        await _pump(tester, design, ratio);
        expect(
          tester.getSize(find.byType(ShareCard)),
          Size(300, height),
          reason: '${design.name} ${ratio.name}',
        );
      }
    }
  });

  testWidgets('is the 4:5 card unless a ratio is given', (tester) async {
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        const ShareCard(
          ayah: _text,
          surahName: _name,
          ayahNumber: 5,
          ayahFontSize: 34,
        ),
      ),
    );
    expect(tester.getSize(find.byType(ShareCard)), const Size(300, 375));
  });

  testWidgets('keeps the paddings: the ayah and the foot keep their width '
      'and their distance from the edges at every ratio', (tester) async {
    for (final design in ShareCardDesign.values) {
      final inset = <ShareCardRatio, (double, double, double)>{};
      for (final ratio in ShareCardRatio.values) {
        await _pump(tester, design, ratio);
        final card = tester.getRect(find.byType(ShareCard));
        final ayah = tester.getRect(find.byType(QuranText));
        final foot = tester.getRect(find.text(_l10n.appTitle));
        inset[ratio] = (
          ayah.left - card.left,
          ayah.width,
          card.bottom - foot.bottom,
        );
      }
      expect(
        inset.values.toSet(),
        hasLength(1),
        reason: '${design.name}: $inset',
      );
    }
  });

  testWidgets('draws the ayah the caller gives, whole, at every ratio', (
    tester,
  ) async {
    for (final design in ShareCardDesign.values) {
      for (final ratio in ShareCardRatio.values) {
        await _pump(tester, design, ratio);
        expect(
          tester.widget<QuranText>(find.byType(QuranText)).text,
          _text,
          reason: '${design.name} ${ratio.name}',
        );
      }
    }
  });
}
