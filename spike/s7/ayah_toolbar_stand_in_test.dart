import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

import 'ayah_toolbar_stand_in.dart';

Future<List<AyahToolbarAction>> _pump(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  final pressed = <AyahToolbarAction>[];
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(theme),
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(child: AyahToolbarStandIn(onAction: pressed.add)),
      ),
    ),
  );
  return pressed;
}

void main() {
  testWidgets('three actions with AyahRow\'s labels, in its order, and no '
      'copy or share', (tester) async {
    await _pump(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(AyahToolbarStandIn)),
    );
    final buttons = tester
        .widgetList<IconButton>(find.byType(IconButton))
        .toList();
    expect(
      [for (final b in buttons) b.icon],
      [IconName.play, IconName.bookmark, IconName.study],
    );
    expect(
      [for (final b in buttons) b.label],
      [l10n.ayahRowPlayFromHere, l10n.ayahRowBookmark, l10n.ayahRowStudy],
    );
  });

  testWidgets('each press reports its action', (tester) async {
    final pressed = await _pump(tester);
    for (final button in find.byType(IconButton).evaluate().toList()) {
      await tester.tap(find.byWidget(button.widget));
    }
    expect(pressed, AyahToolbarAction.values);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('targets of at least 48 and labelled buttons in '
        '${theme.name}', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, theme: theme);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }

  testWidgets('nothing overflows at 200% text', (tester) async {
    await _pump(tester, textScale: 2);
    expect(tester.takeException(), isNull);
  });
}
