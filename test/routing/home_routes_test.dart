import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes/home_routes.dart';
import 'package:holyquran/routing/routes/listen_routes.dart';
import 'package:holyquran/routing/routes/more_routes.dart';
import 'package:holyquran/routing/routes/mushaf_routes.dart';
import 'package:holyquran/routing/routes/study_routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:provider/provider.dart';

import '../../testing/fakes/fake_app_settings_repository.dart';
import '../../testing/fakes/fake_pack_integrity_repository.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

const _testCopy = (id: 'unapproved-synthetic', version: 1);

Future<void> _pump(
  WidgetTester tester,
  ({String id, int version})? basePack,
) async {
  final router = createRouter(
    features: [
      homeRoutesFor(basePack),
      mushafRoutes,
      listenRoutes,
      studyRoutes,
      moreRoutes,
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsRepository>.value(
          value: FakeAppSettingsRepository(),
        ),
        ListenableProvider<PackIntegrityRepository>.value(
          value: FakePackIntegrityRepository({
            _testCopy.id: const IntegrityFailed(
              PackInconsistent('unapproved-synthetic', 'synthetic'),
            ),
          }),
        ),
      ],
      child: QuranApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home shows the alert when the test copy pack failed', (
    tester,
  ) async {
    await _pump(tester, _testCopy);

    expect(find.byType(IntegrityAlert), findsOneWidget);
    expect(find.text(_l10n.integrityBaseTitle), findsOneWidget);
  });

  testWidgets('home shows no alert when the build reads no base pack', (
    tester,
  ) async {
    await _pump(tester, null);

    expect(find.byType(IntegrityAlert), findsNothing);
  });
}
