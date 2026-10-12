import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/settings_store.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/utils/result.dart';

final class _FailingDao extends SettingsDao {
  _FailingDao(super.attachedDatabase);

  @override
  Future<void> write(
    String key,
    StoredSetting value, {
    required int updatedAt,
  }) async => throw const FormatException('synthetic failure');
}

Future<LocalAppSettingsRepository> _repository(SettingsDao dao) async =>
    LocalAppSettingsRepository(await SettingsStore.load(dao));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;

  setUp(() => db = UserDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('defaults before anything is stored', () async {
    final settings = await _repository(SettingsDao(db));

    expect(settings.themePreference, const ThemePreference());
    expect(settings.level, UiLevel.simple);
    expect(settings.levelChosen, isFalse);
    expect(settings.openAtLastPosition, isFalse);
    expect(settings.keepScreenAwake, isTrue);
    expect(settings.surahTextScale, 1.0);
  });

  test('every setter stores its value and notifies once', () async {
    final settings = await _repository(SettingsDao(db));
    var notified = 0;
    settings.addListener(() => notified++);

    final results = [
      await settings.setTheme(ReadingTheme.sepia),
      await settings.setFollowSystemDark(true),
      await settings.setLevel(UiLevel.study),
      await settings.setLevelChosen(true),
      await settings.setOpenAtLastPosition(true),
      await settings.setKeepScreenAwake(false),
      await settings.setSurahTextScale(1.5),
    ];

    expect(results, everyElement(isA<Ok<void>>()));
    expect(notified, 7);
    final reloaded = await _repository(SettingsDao(db));
    for (final read in [settings, reloaded]) {
      expect(
        read.themePreference,
        const ThemePreference(
          theme: ReadingTheme.sepia,
          followSystemDark: true,
        ),
      );
      expect(read.level, UiLevel.study);
      expect(read.levelChosen, isTrue);
      expect(read.openAtLastPosition, isTrue);
      expect(read.keepScreenAwake, isFalse);
      expect(read.surahTextScale, 1.5);
    }
  });

  test('a failed write returns a Failure and does not notify', () async {
    final settings = await _repository(_FailingDao(db));
    var notified = 0;
    settings.addListener(() => notified++);

    final result = await settings.setLevel(UiLevel.medium);

    expect(result, isA<Failure<void>>());
    expect(notified, 0);
    expect(settings.level, UiLevel.simple);
  });

  test('settings survive closing and reopening a file database', () async {
    final directory = await Directory.systemTemp.createTemp('settings_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}');

    final first = UserDatabase(NativeDatabase(file));
    final settings = await _repository(SettingsDao(first));
    await settings.setTheme(ReadingTheme.contrast);
    await settings.setLevel(UiLevel.medium);
    await first.close();

    final second = UserDatabase(NativeDatabase(file));
    addTearDown(second.close);
    final reopened = await _repository(SettingsDao(second));
    expect(reopened.themePreference.theme, ReadingTheme.contrast);
    expect(reopened.level, UiLevel.medium);
  });
}
