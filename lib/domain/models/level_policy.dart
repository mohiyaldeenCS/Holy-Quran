import 'package:holyquran/domain/models/ui_level.dart';

/// The Phase 1 tools, by the rows of PRD §7.3, and the word sheet that §7.4
/// opens from a tap on a word. Rows of later phases join with their tools.
enum LevelTool {
  /// The reader in both modes, the index and the last position.
  reader,

  /// The player, ranges, repetition and downloads.
  playback,

  /// Bookmarks, notes, copying and sharing.
  ayahTools,

  /// Tafsir on request and text search.
  tafsirAndSearch,

  /// The word sheet; at «بسيط» a tap on a word shows or hides the interface.
  wordSheet,
}

/// What each level shows by default (PRD §7.3, `LV-03`). A tool of a higher
/// level opened by a link still works (`LV-04`).
abstract final class LevelPolicy {
  /// The lowest level that shows [tool].
  static UiLevel minimumLevel(LevelTool tool) => switch (tool) {
    LevelTool.reader ||
    LevelTool.playback ||
    LevelTool.ayahTools ||
    LevelTool.tafsirAndSearch => UiLevel.simple,
    LevelTool.wordSheet => UiLevel.medium,
  };

  static bool shows(LevelTool tool, UiLevel level) =>
      level.index >= minimumLevel(tool).index;
}
