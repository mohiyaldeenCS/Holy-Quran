import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/level_policy.dart';
import 'package:holyquran/domain/models/ui_level.dart';

void main() {
  test('the default level is «بسيط» (LV-01)', () {
    expect(UiLevel.initial, UiLevel.simple);
  });

  test('the levels are ordered simple, medium, study', () {
    expect(UiLevel.values, [UiLevel.simple, UiLevel.medium, UiLevel.study]);
  });

  // PRD §7.3, Phase 1 rows; the word sheet by §7.4.
  const table = {
    LevelTool.reader: [true, true, true],
    LevelTool.playback: [true, true, true],
    LevelTool.ayahTools: [true, true, true],
    LevelTool.tafsirAndSearch: [true, true, true],
    LevelTool.wordSheet: [false, true, true],
  };

  test('the table covers every tool', () {
    expect(table.keys, unorderedEquals(LevelTool.values));
  });

  for (final MapEntry(key: tool, value: shown) in table.entries) {
    for (final level in UiLevel.values) {
      test('${tool.name} at ${level.name}: ${shown[level.index]}', () {
        expect(LevelPolicy.shows(tool, level), shown[level.index]);
      });
    }
  }

  test('the minimum level is the lowest that shows a tool', () {
    for (final tool in LevelTool.values) {
      expect(
        LevelPolicy.minimumLevel(tool),
        UiLevel.values.firstWhere((level) => table[tool]![level.index]),
      );
    }
  });
}
