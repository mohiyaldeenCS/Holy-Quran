import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/data/repositories/app_settings_repository.dart';
import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/utils/result.dart';

/// Provides the [AppSettingsRepository] over the user database, every
/// setting read before the first frame (D-105). Settings that cannot be read
/// stop the start rather than show the app without the user's choices.
Future<void> settingsProviders(Dependencies dependencies) async {
  final dao = SettingsDao(dependencies.read<UserDatabase>());
  final settings = switch (await LocalAppSettingsRepository.load(dao)) {
    Ok(:final value) => value,
    Failure(:final error) => throw error,
  };
  dependencies.provideListenable<AppSettingsRepository>(settings);
}
