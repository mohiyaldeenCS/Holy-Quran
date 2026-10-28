import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/share/share_card_fit.dart';
import 'package:holyquran/ui/core/share/share_card_sheet.dart';
import 'package:holyquran/ui/core/share/share_card_sheet_view.dart';
import 'package:holyquran/ui/core/share/share_card_sheet_view_model.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/golden.dart';
import '../../../integrity/pack_integrity_suite.dart';
import 'share_test_pack.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

// Synthetic ayah and surah name.
const _text = PackText.fromPack('نص تجريبي للاختبار وليس آية');
const _name = PackText.fromPack('اسم تجريبي');

const _card = ShareCard(
  ayah: _text,
  surahName: _name,
  ayahNumber: 5,
  ayahFontSize: shareCardFontSize,
);

Future<void> _pump(
  WidgetTester tester,
  Widget sheet, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Align(alignment: Alignment.bottomCenter, child: sheet),
        ),
      ),
    ),
  );
}

ShareCardSheet _sheet({
  ShareCard? card = _card,
  VoidCallback? onShare,
  VoidCallback? onCopy,
  ValueChanged<ShareCardDesign>? onDesignSelected,
}) => ShareCardSheet(
  design: ShareCardDesign.emerald,
  onDesignSelected: onDesignSelected ?? (_) {},
  card: card,
  onShare: onShare,
  onCopy: onCopy ?? () {},
);

Finder _button(String label) => find.widgetWithText(Button, label);

void main() {
  group('ShareCardSheet', () {
    testWidgets('offers the three designs, previews the card and shares it', (
      tester,
    ) async {
      final designs = <ShareCardDesign>[];
      var shared = 0;
      await _pump(
        tester,
        _sheet(onShare: () => shared++, onDesignSelected: designs.add),
      );
      final level = tester.widget<LevelSwitch>(find.byType(LevelSwitch));
      expect(level.options, [
        _l10n.shareDesignEmerald,
        _l10n.shareDesignPaper,
        _l10n.shareDesignNight,
      ]);
      expect(level.selectedIndex, 0);
      expect(level.semanticLabel, _l10n.shareDesignSwitchLabel);
      expect(find.byWidget(_card), findsOneWidget);
      expect(find.text(_l10n.shareTooLong), findsNothing);

      await tester.tap(find.text(_l10n.shareDesignNight));
      expect(designs, [ShareCardDesign.night]);
      await tester.tap(_button(_l10n.toolbarShare));
      expect(shared, 1);
    });

    testWidgets('the share button is disabled without onShare', (tester) async {
      await _pump(tester, _sheet());
      expect(
        tester.widget<Button>(_button(_l10n.toolbarShare)).onPressed,
        isNull,
      );
    });

    testWidgets('an ayah too long for any card is said so, with copy', (
      tester,
    ) async {
      var copies = 0;
      await _pump(tester, _sheet(card: null, onCopy: () => copies++));
      expect(find.byType(ShareCard), findsNothing);
      expect(find.text(_l10n.shareTooLong), findsOneWidget);
      expect(_button(_l10n.toolbarShare), findsNothing);
      await tester.tap(_button(_l10n.copyAction));
      expect(copies, 1);
    });

    for (final theme in ReadingTheme.values) {
      for (final scale in [1.0, 2.0]) {
        for (final card in [_card, null]) {
          testWidgets('lays out without overflow in ${theme.name} at '
              '${(scale * 100).round()}% on 360 wide, '
              '${card == null ? 'too long' : 'with a card'}', (tester) async {
            await _pump(
              tester,
              _sheet(card: card, onShare: () {}),
              theme: theme,
              textScale: scale,
            );
            expect(tester.takeException(), isNull);
            expect(
              tester.getSize(find.byType(LevelSwitch)).width,
              lessThanOrEqualTo(360),
            );
          });
        }
      }
    }
  });

  group('ShareCardSheetView with the synthetic pack', () {
    late PackUnderTest pack;
    late List<PackAyah> ayat;

    setUpAll(() async {
      pack = await loadShareTestPack();
      ayat = await packAyat(pack, pack.openRepository());
    });

    Future<List<Uint8List>> pumpView(
      WidgetTester tester,
      QuranAddress address, {
      VoidCallback? onCopy,
    }) async {
      final shared = <Uint8List>[];
      await _pump(
        tester,
        ShareCardSheetView(
          create: () => ShareCardSheetViewModel(
            address: address,
            repository: pack.openRepository(),
            shareImage: (png, {required fileName}) async {
              shared.add(png);
              return const Ok(null);
            },
          ),
          onCopy: onCopy ?? () {},
        ),
      );
      await tester.pump();
      await tester.pump();
      return shared;
    }

    testWidgets('fits the ayah, previews it at its size and shares the '
        'painted card', (tester) async {
      final ayah = shortestAndLongest(ayat, 1).first;
      final shared = await pumpView(tester, ayah.address);
      final card = tester.widget<ShareCard>(find.byType(ShareCard));
      expect(card.ayah, ayah.text);
      expect(card.surahName, ayah.surahName);
      expect(card.ayahNumber, ayah.address.ayah);
      expect(card.ayahFontSize, shareCardFontSize);
      expect(card.design, ShareCardDesign.emerald);

      await tester.tap(find.text(_l10n.shareDesignPaper));
      await tester.pump();
      expect(
        tester.widget<ShareCard>(find.byType(ShareCard)).design,
        ShareCardDesign.paper,
      );

      await tester.tap(_button(_l10n.toolbarShare));
      await tester.runAsync(() async {
        while (shared.isEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(shared.single.sublist(1, 4), 'PNG'.codeUnits);
    });

    testWidgets('the share button is disabled while a share runs', (
      tester,
    ) async {
      final pending = Completer<Result<void>>();
      await _pump(
        tester,
        ShareCardSheetView(
          create: () => ShareCardSheetViewModel(
            address: shortestAndLongest(ayat, 1).first.address,
            repository: pack.openRepository(),
            shareImage: (png, {required fileName}) => pending.future,
          ),
          onCopy: () {},
        ),
      );
      await tester.pump();
      await tester.pump();
      Button share() => tester.widget<Button>(_button(_l10n.toolbarShare));
      expect(share().onPressed, isNotNull);
      await tester.tap(_button(_l10n.toolbarShare));
      await tester.pump();
      expect(share().onPressed, isNull);
      pending.complete(const Ok(null));
    });

    testWidgets('an ayah no 4:5 card holds is too long, and offers copy', (
      tester,
    ) async {
      var copies = 0;
      await pumpView(
        tester,
        shortestAndLongest(ayat, 1).last.address,
        onCopy: () => copies++,
      );
      expect(find.byType(ShareCard), findsNothing);
      expect(find.text(_l10n.shareTooLong), findsOneWidget);
      await tester.tap(_button(_l10n.copyAction));
      expect(copies, 1);
    });

    testWidgets('shows nothing until the ayah is read, nor when it fails', (
      tester,
    ) async {
      final address = ayat.first.address;
      await pumpView(tester, QuranAddress(address.riwaya, address.surah, 999));
      expect(find.byType(ShareCardSheet), findsNothing);
    });
  });
}
