import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/share_providers.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/clipboard_service.dart';
import 'package:holyquran/data/services/share_service.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/copy_form.dart';
import 'package:holyquran/domain/models/unapproved_copy_mark.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/share/ayah_copy_text.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../integrity/pack_integrity_suite.dart';
import '../../ui/core/share/share_test_pack.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  test('provides the system clipboard and share services', () async {
    late Dependencies provided;
    await buildDependencies(
      areas: [shareProviders, (dependencies) async => provided = dependencies],
    );
    expect(provided.read<ClipboardService>(), isA<SystemClipboardService>());
    expect(provided.read<ShareService>(), isA<SystemShareService>());
  });

  test('an approved build provides both, and no mark', () async {
    late Dependencies provided;
    await buildDependencies(
      areas: [
        (dependencies) => provideShare(dependencies, unapprovedCopy: false),
        (dependencies) async => provided = dependencies,
      ],
    );
    expect(provided.read<ClipboardService>(), isA<SystemClipboardService>());
    expect(provided.read<ShareService>(), isA<SystemShareService>());
    expect(provided.tryRead<UnapprovedCopyMark>(), isNull);
  });

  test('the unapproved test copy keeps the clipboard, marks itself and '
      'offers no share as an image', () async {
    late Dependencies provided;
    await buildDependencies(
      areas: [
        (dependencies) => provideShare(dependencies, unapprovedCopy: true),
        (dependencies) async => provided = dependencies,
      ],
    );
    expect(provided.read<ClipboardService>(), isA<SystemClipboardService>());
    expect(provided.tryRead<UnapprovedCopyMark>(), isNotNull);
    expect(provided.tryRead<ShareService>(), isNull);
  });

  group('the sheets through the composition root', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const share = MethodChannel('dev.fluttercommunity.plus/share');
    // share_plus stages the image in the temporary directory.
    const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
    late PackUnderTest pack;
    late List<PackAyah> ayat;
    late Directory temp;
    late List<String> clipboard;
    late List<MethodCall> shares;

    setUpAll(() async {
      pack = await loadShareTestPack();
      ayat = await packAyat(pack, pack.openRepository());
    });

    setUp(() {
      temp = Directory.systemTemp.createTempSync('share_providers');
      clipboard = [];
      shares = [];
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard.add((call.arguments as Map)['text'] as String);
          }
          return null;
        })
        ..setMockMethodCallHandler(share, (call) async {
          shares.add(call);
          return '';
        })
        ..setMockMethodCallHandler(pathProvider, (call) async => temp.path);
    });

    tearDown(() {
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(share, null)
        ..setMockMethodCallHandler(pathProvider, null);
      temp.deleteSync(recursive: true);
    });

    // The app's own providers; no base pack is bundled yet (B0.2), so the
    // synthetic pack stands in for the Quran area's repository.
    Future<GoRouter> pumpApp(
      WidgetTester tester, {
      bool unapprovedCopy = false,
    }) async {
      final providers = (await tester.runAsync(
        () => buildDependencies(
          areas: [
            for (final area in appAreas)
              area == shareProviders
                  ? (dependencies) => provideShare(
                      dependencies,
                      unapprovedCopy: unapprovedCopy,
                    )
                  : area,
          ],
        ),
      ))!;
      final router = createRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...providers,
            Provider<QuranTextRepository>.value(value: pack.openRepository()),
          ],
          child: QuranApp(router: router),
        ),
      );
      await tester.pumpAndSettle();
      // The user database opens in [temp], which tearDown deletes.
      addTearDown(
        tester.element(find.byType(QuranApp)).read<UserDatabase>().close,
      );
      return router;
    }

    testWidgets('the copy sheet copies through the clipboard service', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      final address = ayat[3].address;
      unawaited(router.push(Routes.copySheet(address)));
      await tester.pumpAndSettle();
      expect(find.byType(CopySheet), findsOneWidget);

      final copy = find.widgetWithText(Button, _l10n.copyAction);
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      await tester.tap(copy);
      await tester.pumpAndSettle();
      final expected = await AyahCopyText(
        pack.openRepository(),
        _l10n,
      ).compose(address, CopyForm.withSurahAndNumber);
      expect(clipboard.map(utf8.encode), [
        utf8.encode((expected as Ok<String>).value),
      ]);
    });

    testWidgets('in the unapproved test copy the copy sheet copies the copy of '
        'an approved build and the marking line after it', (tester) async {
      final router = await pumpApp(tester, unapprovedCopy: true);
      final address = ayat[3].address;
      unawaited(router.push(Routes.copySheet(address)));
      await tester.pumpAndSettle();
      expect(find.byType(CopySheet), findsOneWidget);

      final copy = find.widgetWithText(Button, _l10n.copyAction);
      await tester.ensureVisible(copy);
      await tester.pumpAndSettle();
      await tester.tap(copy);
      await tester.pumpAndSettle();
      final approved = await AyahCopyText(
        pack.openRepository(),
        _l10n,
      ).compose(address, CopyForm.withSurahAndNumber);
      expect(clipboard.map(utf8.encode), [
        [
          ...utf8.encode((approved as Ok<String>).value),
          0x0A,
          ...utf8.encode(_l10n.unapprovedTestCopy),
        ],
      ]);
    });

    testWidgets('in the unapproved test copy the share sheet does not open', (
      tester,
    ) async {
      final router = await pumpApp(tester, unapprovedCopy: true);
      unawaited(
        router.push(
          Routes.shareSheet(shortestAndLongest(ayat, 1).first.address),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ShareCard), findsNothing);
      expect(find.widgetWithText(Button, _l10n.toolbarShare), findsNothing);
      expect(shares, isEmpty);
    });

    testWidgets('the share sheet shares through the share service', (
      tester,
    ) async {
      final router = await pumpApp(tester);
      unawaited(
        router.push(
          Routes.shareSheet(shortestAndLongest(ayat, 1).first.address),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ShareCard), findsOneWidget);

      final button = find.widgetWithText(Button, _l10n.toolbarShare);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      // Painting and staging the image take real time; what follows them
      // runs as the test's clock moves.
      for (var wait = 0; shares.isEmpty && wait < 500; wait++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(shares.map((call) => call.method), ['share']);
    });
  });
}
