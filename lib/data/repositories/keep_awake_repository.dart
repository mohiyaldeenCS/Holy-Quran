import 'package:flutter/foundation.dart';

import 'package:holyquran/data/services/wakelock_service.dart';
import 'package:holyquran/utils/result.dart';

/// Keeps the screen on while the setting is on and the reader is open or
/// recitation plays (`RD-16`), and whenever stand mode is on, setting or no
/// setting (`SY-05`). Listeners hear when [awake] changes.
abstract class KeepAwakeRepository extends ChangeNotifier {
  /// Whether the screen is being kept on.
  bool get awake;

  Future<Result<void>> setSettingOn(bool on);
  Future<Result<void>> setReaderActive(bool active);
  Future<Result<void>> setPlayerActive(bool active);

  /// Stand mode prevents the screen from turning off whatever the setting.
  Future<Result<void>> setStandActive(bool active);
}

/// [KeepAwakeRepository] over the wakelock. It starts with every input off
/// and calls the wakelock only when [awake] should change.
final class LocalKeepAwakeRepository extends KeepAwakeRepository {
  LocalKeepAwakeRepository(this._wakelock);

  final WakelockService _wakelock;
  bool _settingOn = false;
  bool _readerActive = false;
  bool _playerActive = false;
  bool _standActive = false;
  bool _awake = false;

  /// Changes run one after another, so the last input decides.
  Future<Result<void>> _queue = Future.value(const Ok(null));

  @override
  bool get awake => _awake;

  @override
  Future<Result<void>> setSettingOn(bool on) {
    _settingOn = on;
    return _follow();
  }

  @override
  Future<Result<void>> setReaderActive(bool active) {
    _readerActive = active;
    return _follow();
  }

  @override
  Future<Result<void>> setPlayerActive(bool active) {
    _playerActive = active;
    return _follow();
  }

  @override
  Future<Result<void>> setStandActive(bool active) {
    _standActive = active;
    return _follow();
  }

  Future<Result<void>> _follow() => _queue = _queue.then(
    (_) => _apply(
      _standActive || (_settingOn && (_readerActive || _playerActive)),
    ),
  );

  Future<Result<void>> _apply(bool awake) async {
    if (awake == _awake) return const Ok(null);
    try {
      await (awake ? _wakelock.enable() : _wakelock.disable());
    } on Exception catch (error) {
      return Failure(error);
    }
    _awake = awake;
    notifyListeners();
    return const Ok(null);
  }
}
