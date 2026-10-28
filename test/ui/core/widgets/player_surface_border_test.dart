import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/continue_card.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/player_panel.dart';
import 'package:holyquran/ui/core/widgets/player_surface_border.dart';
import 'package:holyquran/ui/core/widgets/reader_player_bar.dart';
import 'package:holyquran/ui/core/widgets/recitation_card.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<Border?> _borderIn(WidgetTester tester, ReadingTheme theme) async {
  Border? border;
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) {
          border = playerSurfaceBorder(context);
          return const SizedBox();
        },
      ),
    ),
  );
  return border;
}

void main() {
  testWidgets('night and contrast border the player in line-strong', (
    tester,
  ) async {
    for (final (theme, colors) in [
      (ReadingTheme.night, AppColors.night),
      (ReadingTheme.contrast, AppColors.contrast),
    ]) {
      expect(
        await _borderIn(tester, theme),
        Border.all(color: colors.lineStrong),
        reason: '$theme',
      );
    }
  });

  testWidgets('paper and sepia keep the surface as the boards draw it', (
    tester,
  ) async {
    expect(await _borderIn(tester, ReadingTheme.paper), isNull);
    expect(await _borderIn(tester, ReadingTheme.sepia), isNull);
  });

  final surah = PackText.fromPack(_l10n.sampleSurahName);
  void noop() {}
  final surfaces = <String, Widget>{
    'MiniPlayer': MiniPlayer(surah: surah, ayah: 1, speed: '1', playing: false),
    'PlayerPanel': PlayerPanel(
      playing: false,
      speed: '1',
      range: 'range',
      silence: 'silence',
      onPlayPause: noop,
      onPrevious: noop,
      onNext: noop,
      onSpeed: noop,
      onRepeat: noop,
      onRange: noop,
      onSilence: noop,
    ),
    'RecitationCard': const RecitationCard(reciter: 'reciter'),
    'ReaderPlayerBar': ReaderPlayerBar(surah: surah, ayah: 1, playing: false),
    'ContinueCard': ContinueCard(surah: surah, onContinue: noop),
  };

  for (final MapEntry(key: name, value: surface) in surfaces.entries) {
    testWidgets('$name takes the border in contrast and none in paper', (
      tester,
    ) async {
      Finder bordered(Border? border) => find.descendant(
        of: find.byType(surface.runtimeType),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).border == border,
        ),
      );
      final border = Border.all(color: AppColors.contrast.lineStrong);

      await tester.pumpWidget(goldenApp(ReadingTheme.contrast, surface));
      expect(bordered(border), findsWidgets);

      await tester.pumpWidget(goldenApp(ReadingTheme.paper, surface));
      expect(
        bordered(Border.all(color: AppColors.paper.lineStrong)),
        findsNothing,
      );
    });
  }
}
