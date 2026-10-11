import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/continue_card.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
final _surah = PackText.fromPack(_l10n.sampleSurahName);
const _colors = AppColors.paper;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
            child: child,
          ),
        ),
      ),
    ),
  );
}

ContinueCard _card({String? meta, VoidCallback? onContinue}) => ContinueCard(
  surah: _surah,
  meta: meta,
  progress: 0.07,
  onContinue: onContinue ?? () {},
);

Finder _button() => find.byType(Pressable);

BoxDecoration _buttonDecoration(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(of: _button(), matching: find.byType(Container)),
            )
            .decoration!
        as BoxDecoration;

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('is player, radius 26, padded 24, its rows 10 apart', (
    tester,
  ) async {
    await _pump(tester, _card(meta: _l10n.sampleMeta));
    expect(
      tester
          .widget<ClipRRect>(
            find
                .descendant(
                  of: find.byType(ContinueCard),
                  matching: find.byType(ClipRRect),
                )
                .first,
          )
          .borderRadius,
      BorderRadius.circular(26),
    );
    expect(
      tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(ContinueCard),
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color,
      _colors.player,
    );
    final column = tester.widget<Column>(
      find.descendant(
        of: find.byType(ContinueCard),
        matching: find.byType(Column),
      ),
    );
    expect(column.spacing, 10);
    final card = tester.getRect(find.byType(ContinueCard));
    final label = tester.getRect(find.text(_l10n.continueReadingLabel));
    expect(label.top - card.top, AppSpacing.space5);
    expect(card.right - label.right, AppSpacing.space5);
  });

  testWidgets('draws the label, title and meta as the reference does', (
    tester,
  ) async {
    await _pump(tester, _card(meta: _l10n.sampleMeta));
    final label = tester.widget<Text>(find.text(_l10n.continueReadingLabel));
    expect(label.style!.fontSize, 13);
    expect(label.style!.fontWeight, FontWeight.w600);
    expect(label.style!.color, _colors.playerAccent);

    final title = tester.widget<SurahName>(find.byType(SurahName));
    expect(title.name, _surah);
    expect(title.format, SurahNameFormat.titled);
    expect(title.style.fontFamily, AppFonts.kufi);
    expect(title.style.fontSize, 32);
    expect(title.style.height, 1.3);
    expect(title.style.fontWeight, FontWeight.w400);
    expect(title.style.color, _colors.onPlayer);
    expect(find.text(_l10n.surahTitle(_l10n.sampleSurahName)), findsOneWidget);

    final meta = tester.widget<Text>(find.text(_l10n.sampleMeta));
    expect(meta.style!.fontSize, 15);
    expect(meta.style!.color, _colors.onPlayerMuted);

    final progress = tester.widget<ProgressBar>(find.byType(ProgressBar));
    expect(progress.tone, ProgressBarTone.player);
    expect(progress.value, 0.07);
    expect(progress.label, _l10n.continueReadingPosition);
  });

  testWidgets('hides the meta line when it is null', (tester) async {
    await _pump(tester, _card());
    expect(find.text(_l10n.sampleMeta), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ContinueCard),
        matching: find.byType(Text),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('draws the faint gold stars 200 wide, 50 past the top left', (
    tester,
  ) async {
    await _pump(tester, _card());
    final stars = tester.widget<StarOutline>(find.byType(StarOutline));
    expect(stars.size, 200);
    expect(stars.stroke, 0.8);
    expect(stars.color, Ramps.gold400);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byType(StarOutline),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.28,
    );
    final card = tester.getRect(find.byType(ContinueCard));
    final starsRect = tester.getRect(find.byType(StarOutline));
    expect(starsRect.topLeft - card.topLeft, const Offset(-50, -50));
  });

  testWidgets('puts the button at the right: on-player, 48 high, radius 16', (
    tester,
  ) async {
    await _pump(tester, _card());
    final decoration = _buttonDecoration(tester);
    expect(decoration.color, _colors.onPlayer);
    expect(
      decoration.borderRadius,
      BorderRadius.circular(AppRadius.radiusButton),
    );
    final text = tester.widget<Text>(find.text(_l10n.continueReadingAction));
    expect(text.style!.fontSize, 16);
    expect(text.style!.fontWeight, FontWeight.w600);
    expect(text.style!.color, _colors.player);
    final button = tester.getRect(_button());
    final textRect = tester.getRect(find.text(_l10n.continueReadingAction));
    final card = tester.getRect(find.byType(ContinueCard));
    expect(button.height, AppSizes.targetMin);
    expect(button.right, card.right - AppSpacing.space5);
    expect(button.left, greaterThan(card.left + AppSpacing.space5));
    expect(button.right - textRect.right, AppSpacing.space5);
  });

  testWidgets('continues when tapped or activated by keyboard', (tester) async {
    var presses = 0;
    await _pump(tester, _card(onContinue: () => presses++));
    await tester.tap(_button());
    expect(presses, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(presses, 2);
  });

  testWidgets('reads the button as one labelled node', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _card(meta: _l10n.sampleMeta));
    final node = tester.getSemantics(_button());
    expect(
      node,
      matchesSemantics(
        label: _l10n.continueReadingAction,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(node.childrenCount, 0);
    expect(
      tester.getSemantics(find.byType(ProgressBar)),
      matchesSemantics(
        label: _l10n.continueReadingPosition,
        value: _l10n.percentValue(arabicDigits(7)),
      ),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _card());
    bool ringDrawn() =>
        tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.byType(FocusRing),
                    matching: find.byType(CustomPaint),
                  )
                  .first,
            )
            .foregroundPainter !=
        null;
    expect(ringDrawn(), isFalse);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(ringDrawn(), isTrue);
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(ringDrawn(), isFalse);
  });

  testWidgets('does not overflow at 200% text on 360 wide', (tester) async {
    await _pump(tester, _card(meta: _l10n.sampleLongText), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(_button()).height,
      greaterThanOrEqualTo(AppSizes.targetMin),
    );
  });
}
