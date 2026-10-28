import 'package:flutter/material.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/small_button.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester,
  Widget alert, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 600)
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
          child: SizedBox(width: 320, child: alert),
        ),
      ),
    ),
  );
}

IntegrityAlert _full(VoidCallback onPressed) => IntegrityAlert(
  title: _l10n.sampleRowLabel,
  body: _l10n.sampleLongText,
  action: (label: _l10n.resourceRedownload, onPressed: onPressed),
);

void main() {
  testWidgets('draws the alert icon and the title in the error colour', (
    tester,
  ) async {
    await _pump(tester, _full(() {}));
    const colors = AppColors.paper;
    final icon = tester.widget<Icon>(find.byType(Icon).first);
    expect(icon.name, IconName.alert);
    expect(icon.color, colors.error);
    expect(
      tester.widget<Text>(find.text(_l10n.sampleRowLabel)).style?.color,
      colors.error,
    );
    expect(
      tester.widget<Text>(find.text(_l10n.sampleLongText)).style?.color,
      colors.ink,
    );
  });

  testWidgets('its action is a small outline button, 44 drawn in a 48 target', (
    tester,
  ) async {
    var pressed = 0;
    await _pump(tester, _full(() => pressed++));
    final button = find.byType(SmallButton);
    expect(tester.widget<SmallButton>(button).outlined, isTrue);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(find.byType(Pressable)).height, 44);
    expect(find.bySemanticsLabel(_l10n.resourceRedownload), findsOneWidget);
    await tester.tap(button);
    expect(pressed, 1);
  });

  testWidgets('leaves out what it is not given', (tester) async {
    await _pump(tester, IntegrityAlert(title: _l10n.connectionFailed));
    expect(find.text(_l10n.connectionFailed), findsOneWidget);
    expect(find.byType(SmallButton), findsNothing);

    await _pump(
      tester,
      IntegrityAlert(
        action: (label: _l10n.resourceRedownload, onPressed: () {}),
      ),
    );
    expect(find.byType(Text), findsOneWidget);
    expect(find.byType(SmallButton), findsOneWidget);
  });

  testWidgets('the icon is decoration; the words are read', (tester) async {
    await _pump(tester, IntegrityAlert(title: _l10n.connectionFailed));
    expect(find.bySemanticsLabel(_l10n.connectionFailed), findsOneWidget);
    expect(tester.widget<Icon>(find.byType(Icon)).semanticLabel, isNull);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out at 200% text in ${theme.name}', (tester) async {
      await _pump(tester, _full(() {}), theme: theme, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'the full alert, the action alone, a title alone',
    tags: ['golden'],
    (tester) async {
      await expectGoldensInThemes(tester, 'integrity_alert', (context) {
        final l10n = AppLocalizations.of(context);
        return SizedBox(
          width: 340,
          child: goldenColumn([
            IntegrityAlert(
              title: l10n.sampleRowLabel,
              body: l10n.sampleLongText,
              action: (label: l10n.resourceRedownload, onPressed: () {}),
            ),
            IntegrityAlert(
              action: (label: l10n.resourceRedownload, onPressed: () {}),
            ),
            IntegrityAlert(title: l10n.connectionFailed),
          ]),
        );
      }, surfaceSize: const Size(400, 420));
    },
  );
}
