import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/data/services/share_service.dart';
import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/share/ayah_copy_text.dart';
import 'package:holyquran/ui/core/share/share_card_sheet.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../integrity/pack_integrity_suite.dart';
import 'share_test_pack.dart';

// The two sheets reached by their routes (lib/routing/routes/share_routes.dart).

final _l10n = lookupAppLocalizations(const Locale('ar'));

final class _Clipboard implements ClipboardService {
  final copied = <String>[];

  @override
  Future<Result<void>> copyText(String text) async {
    copied.add(text);
    return const Ok(null);
  }
}

final class _Share implements ShareService {
  @override
  Future<Result<void>> shareImage(
    Uint8List png, {
    required String fileName,
  }) async => const Ok(null);
}

void main() {
  late PackUnderTest pack;
  late List<PackAyah> ayat;

  setUpAll(() async {
    pack = await loadShareTestPack();
    ayat = await packAyat(pack, pack.openRepository());
  });

  Future<(GoRouter, _Clipboard)> pumpApp(WidgetTester tester) async {
    final router = createRouter();
    final clipboard = _Clipboard();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<QuranTextRepository>.value(value: pack.openRepository()),
          Provider<ClipboardService>.value(value: clipboard),
          Provider<ShareService>.value(value: _Share()),
        ],
        child: QuranApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    return (router, clipboard);
  }

  testWidgets('the copy sheet copies the ayah of its address and closes', (
    tester,
  ) async {
    final (router, clipboard) = await pumpApp(tester);
    final address = ayat[5].address;
    unawaited(router.push(Routes.copySheet(address)));
    await tester.pumpAndSettle();
    expect(find.byType(CopySheet), findsOneWidget);

    await tester.tap(find.widgetWithText(Button, _l10n.copyAction));
    await tester.pumpAndSettle();
    final expected = await AyahCopyText(
      pack.openRepository(),
      _l10n,
    ).compose(address, CopyForm.withSurahAndNumber);
    expect(clipboard.copied.map(utf8.encode), [
      utf8.encode((expected as Ok<String>).value),
    ]);
    expect(find.byType(CopySheet), findsNothing);
  });

  testWidgets('the share sheet shows the card of its address', (tester) async {
    final (router, _) = await pumpApp(tester);
    final ayah = shortestAndLongest(ayat, 1).first;
    unawaited(router.push(Routes.shareSheet(ayah.address)));
    await tester.pumpAndSettle();
    final card = tester.widget<ShareCard>(find.byType(ShareCard));
    expect(card.ayah, ayah.text);
    expect(card.ayahNumber, ayah.address.ayah);
  });

  testWidgets('the share sheet of a too long ayah opens the copy sheet in '
      'its place', (tester) async {
    final (router, clipboard) = await pumpApp(tester);
    final address = shortestAndLongest(ayat, 1).last.address;
    unawaited(router.push(Routes.shareSheet(address)));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.shareTooLong), findsOneWidget);

    await tester.tap(find.widgetWithText(Button, _l10n.copyAction));
    await tester.pumpAndSettle();
    expect(find.byType(ShareCardSheet), findsNothing);
    expect(find.byType(CopySheet), findsOneWidget);

    await tester.tap(find.widgetWithText(Button, _l10n.copyAction));
    await tester.pumpAndSettle();
    final expected = await AyahCopyText(
      pack.openRepository(),
      _l10n,
    ).compose(address, CopyForm.withSurahAndNumber);
    expect(clipboard.copied.map(utf8.encode), [
      utf8.encode((expected as Ok<String>).value),
    ]);
  });

  testWidgets('a sheet location opened cold does not show the sheet', (
    tester,
  ) async {
    final (router, _) = await pumpApp(tester);
    router.go(Routes.copySheet(QuranAddress(ayat.first.address.riwaya, 1, 1)));
    await tester.pumpAndSettle();
    expect(find.byType(CopySheet), findsNothing);
  });
}
