import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

import '../lib/tokens_writer.dart';

/// The committed outputs compile and hold what the sources say.
void main() {
  final tokens =
      jsonDecode(File(tokensSourcePath).readAsStringSync())
          as Map<String, Object?>;
  final themes =
      (tokens['color']! as Map<String, Object?>)['themes']! as List<Object?>;
  final themeIds = [
    for (final theme in themes) (theme! as Map<String, Object?>)['id'],
  ];

  test('colour and shadow instances exist for every theme', () {
    expect(AppColors.byId.keys, themeIds);
    expect(AppShadows.byId.keys, themeIds);
    expect(AppShadows.contrast.shadowCard, isEmpty);
    expect(AppShadows.paper.shadowSheet, hasLength(1));
  });

  test('aliases resolve to the ramp values they name', () {
    expect(AppColors.paper.ground, Ramps.paper100);
    expect(AppColors.paper.quranInk, AppColors.paper.ink);
    expect(AppColors.night.quranInk, AppColors.night.ink);
    expect(AppColors.night.primary, Ramps.gold400);
  });

  test('rgba values keep their exact alpha', () {
    expect(AppColors.paper.highlightAyah.a, 0.24);
    expect(AppColors.paper.highlightAyah.r, 184 / 255);
  });

  test('copyWith and lerp are generated', () {
    final copy = AppColors.paper.copyWith(ground: AppColors.night.ground);
    expect(copy.ground, AppColors.night.ground);
    expect(copy.ink, AppColors.paper.ink);
    expect(AppColors.paper.lerp(AppColors.night, 1).ink, AppColors.night.ink);
    expect(
      AppShadows.paper.lerp(AppShadows.night, 1).shadowCard,
      AppShadows.night.shadowCard,
    );
  });

  test('text styles follow the rules of the identity', () {
    expect(AppTextStyles.body.fontFamily, AppFonts.sans);
    expect(
      AppTextStyles.body.leadingDistribution,
      TextLeadingDistribution.even,
    );
    expect(AppTextStyles.body.letterSpacing, 0);
    expect(AppTextStyles.body.color, isNull);
    expect(AppTextStyles.quranPage.fontFamily, AppFonts.quran);
    expect(AppTextStyles.quranPage.fontFamilyFallback, isNull);
    expect(AppTextStyles.display.fontFamilyFallback, [AppFonts.sans]);
    expect(AppRadius.radiusFull, 9999);
    expect(AppSizes.iconStroke, 1.75);
  });

  test('icons build on the 24 grid and the book on the 120 grid', () {
    expect(IconName.values, hasLength(26));
    for (final name in IconName.values) {
      final bounds = buildIconPath(name).getBounds();
      expect(
        const Rect.fromLTWH(0, 0, 24, 24).contains(bounds.topLeft),
        isTrue,
      );
      expect(
        bounds.right <= 24 && bounds.bottom <= 24,
        isTrue,
        reason: '$name',
      );
    }
    expect(isIconFilled(IconName.play), isTrue);
    expect(isIconFilled(IconName.home), isFalse);
    final book = buildMarkBookPath().getBounds();
    expect(book.left, 38.5);
    expect(book.right, 81.5);
  });
}
