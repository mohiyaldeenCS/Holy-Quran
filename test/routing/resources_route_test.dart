import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/catalogue_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/services/free_space_service.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/features/resources/views/resources_screen.dart';
import 'package:provider/provider.dart';

import '../../testing/application_support.dart';
import '../../testing/fakes/fake_catalogue_repository.dart';
import '../../testing/fakes/fake_pack_install_repository.dart';
import '../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../testing/test_app.dart';

final class _SpyFreeSpace implements FreeSpaceService {
  final asked = <String>[];

  @override
  Future<int?> freeBytesAt(String directory) async {
    asked.add(directory);
    return 1 << 30;
  }
}

// The resource manager reads the device's free space from the service the
// app provides, on the folder the packs are installed in.
void main() {
  Future<void> pumpResources(
    WidgetTester tester, {
    FreeSpaceService? freeSpace,
  }) async {
    final catalogue = FakeCatalogueRepository(syntheticCatalogue());
    final installs = FakePackInstallRepository();
    final integrity = FakePackIntegrityRepository();
    addTearDown(catalogue.dispose);
    addTearDown(installs.dispose);
    addTearDown(integrity.dispose);
    final router = createRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ListenableProvider<CatalogueRepository?>.value(value: catalogue),
          ListenableProvider<PackInstallRepository?>.value(value: installs),
          ListenableProvider<PackIntegrityRepository?>.value(value: integrity),
          Provider<FreeSpaceService?>.value(value: freeSpace),
        ],
        child: testApp(router),
      ),
    );
    router.go(Routes.resources);
    await tester.pumpAndSettle();
  }

  testWidgets('asks the provided service for the space of the support '
      'folder', (tester) async {
    final support = useTemporaryApplicationSupport();
    final space = _SpyFreeSpace();

    await pumpResources(tester, freeSpace: space);
    await pumpUntil(tester, () => space.asked.isNotEmpty);

    expect(space.asked, [support.path]);
    expect(
      tester.widget<ResourcesScreen>(find.byType(ResourcesScreen)).viewModel,
      isNotNull,
    );
  });

  testWidgets('still builds the screen when the app provides no service', (
    tester,
  ) async {
    useTemporaryApplicationSupport();

    await pumpResources(tester);

    expect(
      tester.widget<ResourcesScreen>(find.byType(ResourcesScreen)).viewModel,
      isNotNull,
    );
  });
}
