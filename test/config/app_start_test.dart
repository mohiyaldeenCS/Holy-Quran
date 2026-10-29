import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/main.dart' as app;
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/splash.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../testing/application_support.dart';
import '../../testing/fakes/fake_app_settings_repository.dart';
import '../../testing/fakes/memory_task_storage.dart';

void main() {
  // The app starts the pack installer, which creates the downloader plugin.
  // Its own storage runs an isolate that outlives the test and makes the
  // engine report a callback into the Dart VM as it shuts down.
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    FileDownloader(persistentStorage: MemoryTaskStorage());
  });

  testWidgets('shows the splash until the dependencies are built', (
    tester,
  ) async {
    final dependencies = Completer<List<SingleChildWidget>>();
    await tester.pumpWidget(app.AppStart(dependencies: dependencies.future));

    expect(find.byType(Splash), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    dependencies.complete([
      ChangeNotifierProvider<AppSettingsRepository>.value(
        value: FakeAppSettingsRepository(),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.byType(Splash), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    final context = tester.element(find.byType(HomeScreen));
    expect(Localizations.localeOf(context), const Locale('ar'));
    expect(Directionality.of(context), TextDirection.rtl);
  });

  testWidgets('the splash is in Arabic, right to left', (tester) async {
    await tester.pumpWidget(
      app.AppStart(dependencies: Completer<List<SingleChildWidget>>().future),
    );

    final context = tester.element(find.byType(Splash));
    expect(Localizations.localeOf(context), const Locale('ar'));
    expect(Directionality.of(context), TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed start is reported and keeps the splash', (
    tester,
  ) async {
    final dependencies = Completer<List<SingleChildWidget>>();
    await tester.pumpWidget(app.AppStart(dependencies: dependencies.future));

    dependencies.completeError(StateError('synthetic'));
    await tester.pump();

    expect(tester.takeException(), isStateError);
    expect(find.byType(Splash), findsOneWidget);
  });

  testWidgets('an unreadable user database no longer stops the start: the '
      'app runs on the defaults in memory and leaves the file as it is', (
    tester,
  ) async {
    final support = useTemporaryApplicationSupport();
    final file = File('${support.path}/${UserDatabase.fileName}')
      ..writeAsStringSync('synthetic text that is not a database file' * 100);
    final bytes = file.readAsBytesSync();
    app.main();
    await pumpUntil(
      tester,
      () => find.byType(HomeScreen).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(find.byType(Splash), findsNothing);
    final home = tester.element(find.byType(HomeScreen));
    final settings = home.read<AppSettingsRepository>();
    expect(settings, isA<LocalAppSettingsRepository>());
    expect(home.colors, same(AppColors.paper));

    await settings.setTheme(ReadingTheme.night);
    await tester.pump();

    expect(
      tester.element(find.byType(HomeScreen)).colors,
      same(AppColors.night),
    );
    await tester.runAsync(home.read<UserDatabase>().close);
    expect(file.readAsBytesSync(), bytes);
  });

  testWidgets('main starts the app on the home tab', (tester) async {
    useTemporaryApplicationSupport();
    app.main();
    await pumpUntil(
      tester,
      () => find.byType(HomeScreen).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.runAsync(
      tester.element(find.byType(HomeScreen)).read<UserDatabase>().close,
    );
  });
}
