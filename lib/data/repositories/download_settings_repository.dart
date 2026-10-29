import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/daos/settings_dao.dart';
import 'package:holyquran/data/services/settings_store.dart';
import 'package:holyquran/utils/result.dart';

/// What the user chose about downloading recitations (`AU-13`, `AU-14`):
/// whether downloads wait for Wi-Fi, and the quality of each recitation.
/// Listeners hear of every change.
abstract class DownloadSettingsRepository extends ChangeNotifier {
  /// Downloads wait for Wi-Fi until the user says otherwise (owner,
  /// 2026-10-29).
  static const wifiOnlyDefault = true;

  bool get wifiOnly;

  /// The quality in kbit/s chosen for [recitationId]; null when none was.
  int? qualityOf(String recitationId);

  Future<Result<void>> setWifiOnly(bool wifiOnly);

  Future<Result<void>> setQuality(String recitationId, int kbps);
}

/// [DownloadSettingsRepository] over the user database's `settings` table,
/// which holds a row per key, so these keys need no migration. It reads its
/// own rows once, as the tafsir repository does.
final class LocalDownloadSettingsRepository extends DownloadSettingsRepository {
  LocalDownloadSettingsRepository._(this._store);

  static Future<LocalDownloadSettingsRepository> load(SettingsDao dao) async =>
      LocalDownloadSettingsRepository._(await SettingsStore.load(dao));

  static const _wifiOnly = 'downloads.wifiOnly';
  static const _qualityPrefix = 'downloads.quality.';

  final SettingsStore _store;

  @override
  bool get wifiOnly =>
      _store.readBool(_wifiOnly) ?? DownloadSettingsRepository.wifiOnlyDefault;

  @override
  int? qualityOf(String recitationId) =>
      _store.readInt('$_qualityPrefix$recitationId');

  @override
  Future<Result<void>> setWifiOnly(bool wifiOnly) =>
      _set(() => _store.writeBool(_wifiOnly, wifiOnly));

  @override
  Future<Result<void>> setQuality(String recitationId, int kbps) =>
      _set(() => _store.writeInt('$_qualityPrefix$recitationId', kbps));

  Future<Result<void>> _set(Future<void> Function() write) async {
    try {
      await write();
    } on Exception catch (error) {
      return Failure(error);
    }
    notifyListeners();
    return const Ok(null);
  }
}

/// [DownloadSettingsRepository] on the defaults, kept in memory: the
/// choices of a start whose user database cannot be read, and the stand-in
/// for tests.
final class InMemoryDownloadSettingsRepository
    extends DownloadSettingsRepository {
  InMemoryDownloadSettingsRepository({
    this.wifiOnly = DownloadSettingsRepository.wifiOnlyDefault,
    Map<String, int> qualities = const {},
  }) : _qualities = {...qualities};

  @override
  bool wifiOnly;
  final Map<String, int> _qualities;

  @override
  int? qualityOf(String recitationId) => _qualities[recitationId];

  @override
  Future<Result<void>> setWifiOnly(bool wifiOnly) async {
    this.wifiOnly = wifiOnly;
    notifyListeners();
    return const Ok(null);
  }

  @override
  Future<Result<void>> setQuality(String recitationId, int kbps) async {
    _qualities[recitationId] = kbps;
    notifyListeners();
    return const Ok(null);
  }
}
