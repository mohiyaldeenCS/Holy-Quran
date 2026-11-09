import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/data/services/share_service.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../testing/fakes/fake_app_settings_repository.dart';
import '../integrity/pack_integrity_suite.dart';
import '../ui/core/share/share_test_pack.dart';
import 'a11y_support.dart';

// The copy and share sheets (SH-01, SH-02) at every size and by keyboard.

final class _Clipboard implements ClipboardService {
  @override
  Future<Result<void>> copyText(String text) async => const Ok(null);
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

  Future<void> open(
    WidgetTester tester,
    String Function(PackAyah ayah) location,
    Size size,
    double textScale,
  ) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsRepository>.value(
            value: FakeAppSettingsRepository(),
          ),
          Provider<QuranTextRepository>.value(value: pack.openRepository()),
          Provider<ClipboardService>.value(value: _Clipboard()),
          Provider<ShareService>.value(value: _Share()),
        ],
        child: QuranApp(router: router),
      ),
    );
    await tester.pumpAndSettle();
    unawaited(router.push(location(ayat[5])));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
  }

  final sheets = <String, String Function(PackAyah ayah)>{
    'copy': (ayah) => Routes.copySheet(ayah.address),
    'share': (ayah) => Routes.shareSheet(ayah.address),
  };

  for (final MapEntry(key: name, value: location) in sheets.entries) {
    for (final view in a11yViews) {
      testWidgets('the $name sheet is accessible: ${view.name}', (
        tester,
      ) async {
        addTearDown(tester.ensureSemantics().dispose);
        await open(tester, location, view.size, view.textScale);
        await expectAccessible(tester);
      });
    }

    testWidgets('the $name sheet is reached by Tab', (tester) async {
      addTearDown(tester.ensureSemantics().dispose);
      await open(tester, location, phonePortrait, 1);
      await expectKeyboardReach(tester);
    });
  }
}
