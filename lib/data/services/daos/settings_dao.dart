import 'package:drift/drift.dart';

import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/data/services/user_tables.dart';

part 'settings_dao.g.dart';

/// A stored setting: exactly one of the values is set.
typedef StoredSetting = ({int? intValue, double? realValue, String? textValue});

@DriftAccessor(tables: [Settings])
class SettingsDao extends DatabaseAccessor<UserDatabase>
    with _$SettingsDaoMixin {
  SettingsDao(super.attachedDatabase);

  Future<Map<String, StoredSetting>> readAll() async => {
    for (final row in await select(settings).get())
      row.key: (
        intValue: row.intValue,
        realValue: row.realValue,
        textValue: row.textValue,
      ),
  };

  Future<void> write(
    String key,
    StoredSetting value, {
    required int updatedAt,
  }) => into(settings).insertOnConflictUpdate(
    SettingsCompanion.insert(
      key: key,
      intValue: Value(value.intValue),
      realValue: Value(value.realValue),
      textValue: Value(value.textValue),
      updatedAt: updatedAt,
    ),
  );
}
