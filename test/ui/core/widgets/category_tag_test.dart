import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/category_tag.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(goldenApp(ReadingTheme.paper, Center(child: child)));

void main() {
  const colors = AppColors.paper;

  testWidgets('each built-in category has its shape, colour and word', (
    tester,
  ) async {
    final expected = {
      BuiltinCategory.memorise: (
        TagShape.circle,
        Ramps.emerald700,
        _l10n.tagMemorise,
      ),
      BuiltinCategory.review: (TagShape.square, Ramps.gold600, _l10n.tagReview),
      BuiltinCategory.study: (TagShape.diamond, colors.info, _l10n.tagStudy),
      BuiltinCategory.important: (
        TagShape.ring,
        colors.error,
        _l10n.tagImportant,
      ),
    };
    for (final MapEntry(key: category, value: look) in expected.entries) {
      await _pump(
        tester,
        CategoryTag(category: category, selected: true, onPressed: () {}),
      );
      final tag = tester.widget<Tag>(find.byType(Tag));
      expect((tag.shape, tag.color, tag.label), look, reason: category.name);
      expect(tag.selected, isTrue);
      expect(categoryName(category, _l10n), look.$3);
    }
  });

  testWidgets('a free tag is a hollow ring in ink-muted, with its name', (
    tester,
  ) async {
    var pressed = 0;
    await _pump(
      tester,
      FreeTag(name: 'وسم تجريبي', selected: false, onPressed: () => pressed++),
    );
    final tag = tester.widget<Tag>(find.byType(Tag));
    expect(tag.shape, TagShape.ring);
    expect(tag.color, colors.inkMuted);
    expect(tag.label, 'وسم تجريبي');
    await tester.tap(find.byType(Tag));
    expect(pressed, 1);
  });

  testWidgets('the four categories never share a shape', (tester) async {
    final shapes = <TagShape>{};
    for (final category in BuiltinCategory.values) {
      await _pump(
        tester,
        CategoryTag(category: category, selected: false, onPressed: () {}),
      );
      shapes.add(tester.widget<Tag>(find.byType(Tag)).shape);
    }
    expect(shapes, hasLength(BuiltinCategory.values.length));
  });
}
