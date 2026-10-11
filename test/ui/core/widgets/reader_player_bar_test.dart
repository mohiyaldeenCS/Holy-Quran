import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/reader_player_bar.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
final _surah = PackText.fromPack(_l10n.sampleSurahName);
const _colors = AppColors.paper;
// Screens.dc.html: the bar is 390 less a 16 margin on each side.
const _width = 358.0;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(390, 800)
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
          child: SizedBox(width: _width, child: child),
        ),
      ),
    ),
  );
}

ReaderPlayerBar _bar({
  String? reciter,
  bool playing = true,
  VoidCallback? onPlayPause,
  VoidCallback? onNext,
}) => ReaderPlayerBar(
  surah: _surah,
  ayah: 4,
  reciter: reciter,
  playing: playing,
  onPlayPause: onPlayPause,
  onNext: onNext,
);

Finder _button(IconName icon) => find.byWidgetPredicate(
  (widget) => widget is PlayerButton && widget.icon == icon,
);

Finder _face(IconName icon) => find.descendant(
  of: _button(icon),
  matching: find.byWidgetPredicate(
    (widget) => widget is Container && widget.decoration != null,
  ),
);

void main() {
  tearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );

  testWidgets('is the board bar: 68 high, radius 26, player, sheet shadow', (
    tester,
  ) async {
    await _pump(tester, _bar(reciter: _l10n.sampleReciter));
    final bar = tester.getRect(find.byType(ReaderPlayerBar));
    expect(bar.height, 68);
    final decoration =
        tester
                .widget<Container>(
                  find
                      .descendant(
                        of: find.byType(ReaderPlayerBar),
                        matching: find.byType(Container),
                      )
                      .first,
                )
                .decoration!
            as BoxDecoration;
    expect(decoration.color, _colors.player);
    expect(decoration.borderRadius, BorderRadius.circular(26));
    expect(decoration.boxShadow, AppShadows.paper.shadowSheet);
  });

  testWidgets('places the buttons where the board draws them', (tester) async {
    await _pump(tester, _bar(reciter: _l10n.sampleReciter));
    final bar = tester.getRect(find.byType(ReaderPlayerBar));
    final main = tester.getRect(_face(IconName.pause));
    final next = tester.getRect(_face(IconName.next));
    final title = tester.getRect(
      find.ancestor(of: find.byType(SurahName), matching: find.byType(Column)),
    );
    // Right to left: play at the right, 14 in; next at the left, 14 in.
    expect(main.size, const Size.square(48));
    expect(bar.right - main.right, 14);
    expect(next.size, const Size.square(44));
    expect(next.left - bar.left, 14);
    expect(main.left - title.right, AppSpacing.space3);
    expect(title.left - next.right, AppSpacing.space3);
    // The next button still takes a 48 target.
    expect(tester.getSize(_button(IconName.next)), const Size.square(48));
  });

  testWidgets('colours the buttons as the board does', (tester) async {
    await _pump(tester, _bar());
    final main = tester.widget<Container>(_face(IconName.pause));
    expect((main.decoration! as BoxDecoration).color, _colors.playerAccent);
    final glyph = tester.widget<Icon>(
      find.descendant(of: _button(IconName.pause), matching: find.byType(Icon)),
    );
    expect(glyph.size, 22);
    expect(glyph.color, Ramps.emerald950);
    final next = tester.widget<Icon>(
      find.descendant(of: _button(IconName.next), matching: find.byType(Icon)),
    );
    expect(next.size, AppSizes.iconSize);
    expect(next.color, _colors.onPlayer);
    expect(
      (tester.widget<Container>(_face(IconName.next)).decoration!
              as BoxDecoration)
          .color,
      isNull,
    );
  });

  testWidgets('titles the surah with the ayah, 16 semibold, then the reciter', (
    tester,
  ) async {
    await _pump(tester, _bar(reciter: _l10n.sampleReciter));
    final title = tester.widget<SurahName>(find.byType(SurahName));
    expect(title.name, _surah);
    expect(title.format, SurahNameFormat.withAyah);
    expect(title.ayah, 4);
    expect(title.style.fontSize, 16);
    expect(title.style.fontWeight, FontWeight.w600);
    expect(title.style.color, _colors.onPlayer);
    expect(
      find.text(
        _l10n.surahAyahReference(_l10n.sampleSurahName, arabicDigits(4)),
      ),
      findsOneWidget,
    );
    final reciter = tester.widget<Text>(find.text(_l10n.sampleReciter));
    expect(reciter.style!.fontSize, 13);
    expect(reciter.style!.color, _colors.onPlayerMuted);
  });

  testWidgets('hides the reciter when it is null', (tester) async {
    await _pump(tester, _bar());
    expect(find.text(_l10n.sampleReciter), findsNothing);
    expect(
      find.descendant(
        of: find.byType(ReaderPlayerBar),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
  });

  testWidgets('plays, pauses and moves on when tapped or by keyboard', (
    tester,
  ) async {
    final presses = <String>[];
    await _pump(
      tester,
      _bar(
        onPlayPause: () => presses.add('main'),
        onNext: () => presses.add('next'),
      ),
    );
    await tester.tap(_button(IconName.pause));
    await tester.tapAt(
      tester.getTopLeft(_button(IconName.next)) + const Offset(1, 1),
    );
    expect(presses, ['main', 'next']);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(presses.last, 'main');
  });

  testWidgets('reads each button as one labelled node', (tester) async {
    final handle = tester.ensureSemantics();
    void call() {}
    await _pump(tester, _bar(onPlayPause: call, onNext: call));
    for (final (icon, label) in [
      (IconName.pause, _l10n.playerPause),
      (IconName.next, _l10n.playerNextAyah),
    ]) {
      final node = tester.getSemantics(_button(icon));
      expect(
        node,
        matchesSemantics(
          label: label,
          isButton: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
        reason: icon.name,
      );
      expect(node.childrenCount, 0, reason: icon.name);
    }
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, _bar(playing: false));
    expect(
      tester.getSemantics(_button(IconName.play)),
      matchesSemantics(
        label: _l10n.playerPlay,
        isButton: true,
        hasEnabledState: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('draws the focus ring in keyboard mode only', (tester) async {
    await _pump(tester, _bar(onPlayPause: () {}));
    bool ringDrawn() =>
        tester
            .widget<CustomPaint>(
              find
                  .descendant(
                    of: find.descendant(
                      of: _button(IconName.pause),
                      matching: find.byType(FocusRing),
                    ),
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

  testWidgets('grows instead of clipping at 200% text on 360 wide', (
    tester,
  ) async {
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
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space4,
              ),
              child: _bar(reciter: _l10n.sampleLongText),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(ReaderPlayerBar)).height,
      greaterThan(68),
    );
  });
}
