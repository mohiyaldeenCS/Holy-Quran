import 'dart:convert';
import 'dart:io';

import 'ayah_toolbar_stand_in.dart';
import 'gesture_log.dart';
import 'target_practice.dart';

/// What an S7 run keeps: the gesture log, the toolbar presses, which the
/// log has no gesture for, and the practice hit rates by rule. Numbers,
/// enum names and addresses only.
final class S7Record {
  S7Record({GestureLog? log}) : log = log ?? GestureLog();

  final GestureLog log;
  final Map<AyahToolbarAction, int> _actions = {};

  Map<AyahToolbarAction, int> get toolbarActions => Map.unmodifiable(_actions);

  void countAction(AyahToolbarAction action) =>
      _actions.update(action, (n) => n + 1, ifAbsent: () => 1);

  Map<String, Object> toJson() => {
    ...log.toJson(),
    'toolbar_actions': {
      for (final MapEntry(:key, :value) in _actions.entries) key.name: value,
    },
    'practice_by_rule': hitRatesJson(hitRatesByRule(log.entries)),
  };
}

/// The S7 log, next to S3's in the spike's support folder.
File s7LogFile(Directory storage) => File('${storage.path}/s7-gestures.json');

/// Writes [record] to [s7LogFile] in [storage], replacing what was there.
Future<File> exportS7Record(Directory storage, S7Record record) async {
  await storage.create(recursive: true);
  return s7LogFile(
    storage,
  ).writeAsString(jsonEncode(record.toJson()), flush: true);
}
