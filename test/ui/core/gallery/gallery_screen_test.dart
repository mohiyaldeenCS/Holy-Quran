import 'package:flutter/material.dart' hide Switch, TabBar;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/router.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/app.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/switch.dart';
import 'package:holyquran/ui/core/widgets/tab_bar.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

final _sectionTitles = [
  _l10n.gallerySectionMark,
  _l10n.gallerySectionLockup,
  _l10n.gallerySectionIcons,
  _l10n.gallerySectionButtons,
  _l10n.gallerySectionIconButtons,
  _l10n.gallerySectionSwitches,
  _l10n.gallerySectionLevelSwitch,
  _l10n.gallerySectionTabBar,
  _l10n.gallerySectionQuranText,
  _l10n.gallerySectionAyahMarker,
  _l10n.gallerySectionSurahHeader,
];

final _themeNames = [
  _l10n.themePaper,
  _l10n.themeNight,
  _l10n.themeSepia,
  _l10n.themeContrast,
];

Future<void> _pumpGallery(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size surface = const Size(400, 800),
}) async {
  tester.view
    ..physicalSize = surface
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(theme),
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const GalleryScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inBlock(ReadingTheme theme, Finder finder) => find.descendant(
  of: find.byWidgetPredicate(
    (widget) => widget is GalleryThemeBlock && widget.theme == theme,
  ),
  matching: finder,
  skipOffstage: false,
);

Future<void> _tapInBlock(
  WidgetTester tester,
  ReadingTheme theme,
  Finder finder,
) async {
  final target = _inBlock(theme, finder).first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}%', (tester) async {
        await _pumpGallery(tester, theme: theme, textScale: scale);

        expect(tester.takeException(), isNull);
        expect(
          find.byType(GalleryThemeBlock, skipOffstage: false),
          findsNWidgets(ReadingTheme.values.length),
        );
      });
    }
  }

  testWidgets('titles the page, each theme and every section', (tester) async {
    await _pumpGallery(tester);

    expect(find.text(_l10n.galleryTitle), findsOneWidget);
    for (final (index, theme) in ReadingTheme.values.indexed) {
      expect(
        _inBlock(theme, find.text(_themeNames[index])),
        findsOneWidget,
        reason: theme.name,
      );
      for (final title in _sectionTitles) {
        expect(
          _inBlock(theme, find.text(title)),
          findsOneWidget,
          reason: '${theme.name}: $title',
        );
      }
    }
  });

  testWidgets('section titles are headers for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpGallery(tester);

    for (final title in [_l10n.galleryTitle, ..._sectionTitles]) {
      expect(
        tester.getSemantics(find.text(title).first),
        isSemantics(label: title, isHeader: true),
        reason: title,
      );
    }
    semantics.dispose();
  });

  testWidgets('the controls keep local state in each theme block', (
    tester,
  ) async {
    await _pumpGallery(tester);
    const theme = ReadingTheme.night;

    bool switchValue() =>
        tester.widget<Switch>(_inBlock(theme, find.byType(Switch)).first).value;
    expect(switchValue(), isTrue);
    await _tapInBlock(tester, theme, find.text(_l10n.gallerySwitchTajweed));
    expect(switchValue(), isFalse);

    await _tapInBlock(tester, theme, find.text(_l10n.levelStudy));
    expect(
      tester
          .widget<LevelSwitch>(_inBlock(theme, find.byType(LevelSwitch)))
          .selectedIndex,
      2,
    );

    await _tapInBlock(tester, theme, find.text(_l10n.tabListen));
    expect(
      tester.widget<TabBar>(_inBlock(theme, find.byType(TabBar))).currentIndex,
      2,
    );

    // The other blocks are unchanged.
    expect(
      tester
          .widget<Switch>(
            _inBlock(ReadingTheme.paper, find.byType(Switch)).first,
          )
          .value,
      isTrue,
    );
  });

  testWidgets('every tap target is at least 48 and labelled', (tester) async {
    final semantics = tester.ensureSemantics();
    // Tall enough for every block to be on screen, where the guidelines look.
    await _pumpGallery(tester, surface: const Size(400, 12000));

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('the gallery route exists in debug builds', (tester) async {
    final router = createRouter();
    await tester.pumpWidget(QuranApp(router: router));
    await tester.pumpAndSettle();

    router.go(Routes.gallery);
    await tester.pumpAndSettle();

    expect(find.byType(GalleryScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.gallery);
  });

  testWidgets('the More tab opens the gallery in debug builds', (tester) async {
    final router = createRouter();
    await tester.pumpWidget(QuranApp(router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n.tabMore));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.galleryTitle));
    await tester.pumpAndSettle();

    expect(find.byType(GalleryScreen), findsOneWidget);
    expect(router.state.uri.path, Routes.gallery);
  });
}
