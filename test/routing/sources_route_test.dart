import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/link_service.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/features/sources/views/sources_screen.dart';
import 'package:provider/provider.dart';

import '../../testing/fakes/fake_link_service.dart';
import '../../testing/test_app.dart';
import '../ui/features/sources/sources_fixtures.dart';

// The route builds the list from what the app provides: the verified base
// pack alone is enough, and with nothing the screen shows its title alone.
void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('sources_route_test');
  });
  tearDown(() => root.delete(recursive: true));

  Future<void> pumpSources(WidgetTester tester, {VerifiedPack? base}) async {
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<LinkService?>.value(value: FakeLinkService()),
          Provider<VerifiedPack?>.value(value: base),
        ],
        child: testApp(router),
      ),
    );
    router.go(Routes.sources);
    await tester.pumpAndSettle();
  }

  testWidgets('lists the base pack when only it is provided', (tester) async {
    final installed = await tester.runAsync(
      () => installedWithSource(root, name: 'Synthetic base source'),
    );
    await pumpSources(
      tester,
      base: VerifiedPack(
        directory: installed!.directory,
        manifest: installed.manifest,
        signatureChecked: false,
      ),
    );

    final screen = tester.widget<SourcesScreen>(find.byType(SourcesScreen));
    expect(screen.viewModel, isNotNull);
    expect(find.text('Synthetic base source'), findsOneWidget);
  });

  testWidgets('shows its title alone when no pack is provided', (tester) async {
    await pumpSources(tester);

    final screen = tester.widget<SourcesScreen>(find.byType(SourcesScreen));
    expect(screen.viewModel, isNull);
  });
}
