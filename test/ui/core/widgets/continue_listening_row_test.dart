import 'package:flutter/material.dart' hide Icon, IconButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/continue_listening_row.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

// Synthetic name and reciter.
const _name = 'اسم تجريبي';
const _packName = PackText.fromPack(_name);
const _reciter = 'قارئ تجريبي';
const _ayah = 10;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: child,
          ),
        ),
      ),
    ),
  );
}

Widget _row({String? reciter = _reciter, VoidCallback? onPlay}) =>
    ContinueListeningRow(
      surahName: _packName,
      ayah: _ayah,
      reciter: reciter,
      onPlay: onPlay ?? () {},
    );

String get _title => _l10n.surahTitleAyahReference(_name, arabicDigits(_ayah));

bool _ringDrawn(WidgetTester tester) =>
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

void main() {
  testWidgets('is a surface card, radius 22, line border, padded 14 by 18', (
    tester,
  ) async {
    for (final theme in ReadingTheme.values) {
      final colors = AppColors.byId[theme.name]!;
      await _pump(tester, _row(), theme: theme);
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(ContinueListeningRow),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = card.decoration! as BoxDecoration;
      expect(decoration.color, colors.surface, reason: theme.name);
      expect(decoration.borderRadius, BorderRadius.circular(22));
      final border = decoration.border! as Border;
      expect(border.top.color, colors.line, reason: theme.name);
      expect(border.top.width, 1);
      expect(
        card.padding,
        const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      );
    }
  });

  testWidgets('writes the label, the surah and ayah, and the reciter', (
    tester,
  ) async {
    await _pump(tester, _row());
    const colors = AppColors.paper;

    final label = tester.widget<Text>(find.text(_l10n.continueListeningLabel));
    expect(label.style!.fontSize, 13);
    expect(label.style!.fontWeight, FontWeight.w600);
    expect(label.style!.color, colors.accent);

    final name = tester.widget<SurahName>(find.byType(SurahName));
    expect(identical(name.name, _packName), isTrue);
    expect(name.format, SurahNameFormat.titledWithAyah);
    expect(name.ayah, _ayah);
    expect(name.style.fontSize, 17);
    expect(name.style.fontWeight, FontWeight.w600);
    expect(name.style.height, 1.5);
    expect(name.style.color, colors.ink);
    expect(find.text(_title), findsOneWidget);

    final reciter = tester.widget<Text>(find.text(_reciter));
    expect(reciter.style!.fontSize, 13);
    expect(reciter.style!.fontWeight, FontWeight.w400);
    expect(reciter.style!.color, colors.inkMuted);
  });

  testWidgets('hides the reciter when it is not known', (tester) async {
    await _pump(tester, _row(reciter: null));
    expect(find.text(_reciter), findsNothing);
    expect(find.text(_title), findsOneWidget);
    expect(find.byType(Text), findsNWidgets(2));
  });

  testWidgets('plays from a 52 solid play button', (tester) async {
    var plays = 0;
    await _pump(tester, _row(onPlay: () => plays++));
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.icon, IconName.play);
    expect(button.tone, IconButtonTone.solid);
    expect(button.size, 52);
    expect(button.label, _l10n.playerPlay);
    await tester.tap(find.byType(IconButton));
    expect(plays, 1);
  });

  testWidgets('puts the text at the right and the button at the left', (
    tester,
  ) async {
    await _pump(tester, _row());
    final card = tester.getRect(find.byType(ContinueListeningRow));
    final label = tester.getRect(find.text(_l10n.continueListeningLabel));
    final button = tester.getRect(find.byType(IconButton));
    expect(label.right, card.right - 1 - 18);
    expect(button.left, card.left + 1 + 18);
  });

  testWidgets('reads its text as one node and labels the play button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _row());
    expect(
      find.bySemanticsLabel(
        '${_l10n.continueListeningLabel}\n$_title\n$_reciter',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(find.byType(IconButton)),
      matchesSemantics(
        label: _l10n.playerPlay,
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(find.bySemanticsLabel(_l10n.playerPlay), findsOneWidget);
    expect(tester.getSemantics(find.byType(IconButton)).hasChildren, isFalse);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('rings the play button in keyboard mode only', (tester) async {
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    await _pump(tester, _row());
    expect(_ringDrawn(tester), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_ringDrawn(tester), isTrue);

    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    await tester.pump();
    expect(_ringDrawn(tester), isFalse);
  });

  testWidgets('wraps without overflow at 200% on 360 wide', (tester) async {
    await _pump(
      tester,
      const ContinueListeningRow(
        surahName: PackText.fromPack('$_name $_name $_name'),
        ayah: 286,
        reciter: '$_reciter $_reciter $_reciter',
        onPlay: _none,
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ContinueListeningRow)).width, 320);
  });
}

void _none() {}
