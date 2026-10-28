import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/settings_providers.dart';
import 'package:holyquran/config/providers/user_database_providers.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/repositories/in_memory_app_settings_repository.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/features/home/views/home_screen.dart';
import 'package:holyquran/ui/features/settings/views/settings_screen.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../testing/application_support.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

Future<Dependencies> _settingsOver(UserDatabase database) async {
  late Dependencies provided;
  await buildDependencies(
    areas: [
      (dependencies) async => dependencies.provide(database),
      settingsProviders,
      (dependencies) async => provided = dependencies,
    ],
  );
  return provided;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('the area', () {
    late UserDatabase db;

    setUp(() => db = UserDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('provides the settings stored in the user database', () async {
      final first = (await _settingsOver(db)).read<AppSettingsRepository>();
      expect(first, isA<LocalAppSettingsRepository>());
      expect(first.themePreference, const ThemePreference());
      expect(first.level, UiLevel.initial);

      await first.setTheme(ReadingTheme.sepia);
      await first.setLevel(UiLevel.study);
      final second = (await _settingsOver(db)).read<AppSettingsRepository>();

      expect(second.themePreference.theme, ReadingTheme.sepia);
      expect(second.level, UiLevel.study);
    });

    test('starts on the defaults in memory when the settings file is '
        'unreadable, and leaves the file as it is', () async {
      final directory = await Directory.systemTemp.createTemp('settings_test');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/${UserDatabase.fileName}')
        ..writeAsStringSync('synthetic text that is not a database file' * 100);
      final bytes = file.readAsBytesSync();
      final unreadable = UserDatabase(NativeDatabase(file));
      addTearDown(unreadable.close);

      final settings = (await _settingsOver(
        unreadable,
      )).read<AppSettingsRepository>();

      expect(settings, isA<InMemoryAppSettingsRepository>());
      expect(settings.themePreference, const ThemePreference());
      expect(settings.level, UiLevel.initial);

      var notified = 0;
      settings.addListener(() => notified++);
      expect(await settings.setTheme(ReadingTheme.night), isA<Ok<void>>());
      expect(settings.themePreference.theme, ReadingTheme.night);
      expect(notified, 1);
      expect(file.readAsBytesSync(), bytes);
    });

    test('starts on the defaults, writing nothing to disk, when application '
        'support cannot be found', () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        _pathProvider,
        (call) async => throw PlatformException(code: 'synthetic'),
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(_pathProvider, null),
      );
      late Dependencies provided;

      await buildDependencies(
        areas: [
          userDatabaseProviders,
          settingsProviders,
          (dependencies) async => provided = dependencies,
        ],
      );
      addTearDown(provided.read<UserDatabase>().close);
      final settings = provided.read<AppSettingsRepository>();

      expect(settings.themePreference, const ThemePreference());
      expect(settings.level, UiLevel.initial);
      expect(await settings.setTheme(ReadingTheme.night), isA<Ok<void>>());
      expect(settings.themePreference.theme, ReadingTheme.night);
    });

    test('needs the user database from the area before it', () async {
      await expectLater(
        buildDependencies(areas: [settingsProviders]),
        throwsStateError,
      );
    });
  });

  group('the app built from the composition root', () {
    Future<UserDatabase> pumpApp(WidgetTester tester, String location) async {
      final providers = (await tester.runAsync(buildDependencies))!;
      final router = createRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: providers,
          child: QuranApp(router: router),
        ),
      );
      router.go(location);
      await tester.pumpAndSettle();
      final db = tester.element(find.byType(QuranApp)).read<UserDatabase>();
      addTearDown(db.close);
      return db;
    }

    Finder segment(String label) => find.descendant(
      of: find.byType(LevelSwitch),
      matching: find.text(label),
    );

    testWidgets('opens the settings screen at its route', (tester) async {
      useTemporaryApplicationSupport();
      await pumpApp(tester, Routes.settings);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('keeps a chosen theme across a restart', (tester) async {
      useTemporaryApplicationSupport();
      final first = await pumpApp(tester, Routes.settings);
      final settings = tester
          .element(find.byType(SettingsScreen))
          .read<AppSettingsRepository>();

      await tester.tap(segment(_l10n.themeNight));
      await pumpUntil(
        tester,
        () => settings.themePreference.theme == ReadingTheme.night,
      );
      await tester.pump();
      expect(
        tester.element(find.byType(SettingsScreen)).colors,
        same(AppColors.night),
      );
      await tester.runAsync(first.close);

      await tester.pumpWidget(const SizedBox());
      await pumpApp(tester, Routes.settings);

      expect(
        tester
            .element(find.byType(SettingsScreen))
            .read<AppSettingsRepository>(),
        isNot(same(settings)),
      );
      expect(
        tester.element(find.byType(SettingsScreen)).colors,
        same(AppColors.night),
      );
    });
  });
}
