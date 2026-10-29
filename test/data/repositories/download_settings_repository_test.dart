import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/utils/result.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;

  setUp(() => db = UserDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'downloads wait for Wi-Fi and no quality is chosen to begin with',
    () async {
      final settings = await LocalDownloadSettingsRepository.load(
        SettingsDao(db),
      );

      expect(settings.wifiOnly, isTrue);
      expect(settings.qualityOf('synthetic-listed'), isNull);
    },
  );

  test(
    'the choices are stored, notified and read back after a restart',
    () async {
      final first = await LocalDownloadSettingsRepository.load(SettingsDao(db));
      var notified = 0;
      first.addListener(() => notified++);

      final results = [
        await first.setWifiOnly(false),
        await first.setQuality('synthetic-listed', 64),
        await first.setQuality('synthetic-other', 128),
      ];

      expect(results, everyElement(isA<Ok<void>>()));
      expect(notified, 3);
      final second = await LocalDownloadSettingsRepository.load(
        SettingsDao(db),
      );
      expect(second.wifiOnly, isFalse);
      expect(second.qualityOf('synthetic-listed'), 64);
      expect(second.qualityOf('synthetic-other'), 128);
    },
  );

  test('a write that fails is reported and changes nothing', () async {
    final settings = await LocalDownloadSettingsRepository.load(
      _FailingDao(db),
    );
    var notified = 0;
    settings.addListener(() => notified++);

    expect(await settings.setWifiOnly(false), isA<Failure<void>>());
    expect(settings.wifiOnly, isTrue);
    expect(notified, 0);
  });
}

final class _FailingDao extends SettingsDao {
  _FailingDao(super.attachedDatabase);

  @override
  Future<void> write(
    String key,
    StoredSetting value, {
    required int updatedAt,
  }) async => throw const FormatException('synthetic failure');
}
