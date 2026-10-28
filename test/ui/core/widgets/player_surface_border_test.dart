import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/player_surface_border.dart';

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

  testWidgets('the mini player takes the border in contrast', (tester) async {
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.contrast,
        MiniPlayer(
          surah: PackText.fromPack(_l10n.sampleSurahName),
          ayah: 1,
          speed: '1',
          playing: false,
        ),
      ),
    );

    final card = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(MiniPlayer),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (card.decoration! as BoxDecoration).border,
      Border.all(color: AppColors.contrast.lineStrong),
    );
  });
}
