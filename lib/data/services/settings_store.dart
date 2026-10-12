import 'package:holyquran/data/services/daos/settings_dao.dart';

/// Typed settings over the `settings` table. Every row is read once by
/// [load], so values are there synchronously before the first frame (D-105);
/// a write goes to the database first and to memory once it is stored. A
/// value missing, or stored as another type, reads as null.
final class SettingsStore {
  SettingsStore._(this._dao, this._values, this._now);

  final SettingsDao _dao;
  final Map<String, StoredSetting> _values;
  final int Function() _now;

  static Future<SettingsStore> load(
    SettingsDao dao, {
    int Function() now = _utcMilliseconds,
  }) async => SettingsStore._(dao, await dao.readAll(), now);

  static int _utcMilliseconds() => DateTime.now().millisecondsSinceEpoch;

  bool? readBool(String key) => switch (_values[key]?.intValue) {
    0 => false,
    1 => true,
    _ => null,
  };

  int? readInt(String key) => _values[key]?.intValue;

  double? readDouble(String key) => _values[key]?.realValue;

  String? readString(String key) => _values[key]?.textValue;

  /// The value of [values] named by the stored string.
  T? readEnum<T extends Enum>(String key, List<T> values) =>
      values.asNameMap()[readString(key)];

  Future<void> writeBool(String key, bool value) =>
      writeInt(key, value ? 1 : 0);

  Future<void> writeInt(String key, int value) =>
      _write(key, (intValue: value, realValue: null, textValue: null));

  Future<void> writeDouble(String key, double value) =>
      _write(key, (intValue: null, realValue: value, textValue: null));

  Future<void> writeString(String key, String value) =>
      _write(key, (intValue: null, realValue: null, textValue: value));

  Future<void> writeEnum(String key, Enum value) =>
      writeString(key, value.name);

  Future<void> _write(String key, StoredSetting value) async {
    await _dao.write(key, value, updatedAt: _now());
    _values[key] = value;
  }
}
