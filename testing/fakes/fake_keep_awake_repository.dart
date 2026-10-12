import 'package:holyquran/data/repositories/keep_awake_repository.dart';
import 'package:holyquran/utils/result.dart';

/// Keep-awake inputs held in memory for view tests, with the rule of
/// `RD-16` and no wakelock.
final class FakeKeepAwakeRepository extends KeepAwakeRepository {
  FakeKeepAwakeRepository({this.settingOn = true});

  bool settingOn;
  bool readerActive = false;
  bool playerActive = false;

  @override
  bool get awake => settingOn && (readerActive || playerActive);

  @override
  Future<Result<void>> setSettingOn(bool on) => _set(() => settingOn = on);

  @override
  Future<Result<void>> setReaderActive(bool active) =>
      _set(() => readerActive = active);

  @override
  Future<Result<void>> setPlayerActive(bool active) =>
      _set(() => playerActive = active);

  Future<Result<void>> _set(void Function() change) async {
    final before = awake;
    change();
    if (awake != before) notifyListeners();
    return const Ok(null);
  }
}
