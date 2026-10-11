import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/gallery/sections/audio_gallery.dart';
import 'package:holyquran/ui/core/widgets/continue_card.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';
import 'package:holyquran/ui/core/widgets/mini_player.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/reader_player_bar.dart';
import 'package:holyquran/ui/core/widgets/resource_row.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester, {
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
          child: const SingleChildScrollView(child: AudioGallery()),
        ),
      ),
    ),
  );
}

Finder _main(IconName icon) => find.byWidgetPredicate(
  (widget) => widget is PlayerButton && widget.icon == icon,
);

void main() {
  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}% on 360 wide', (tester) async {
        await _pump(tester, theme: theme, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('titles its five sections and shows each widget', (tester) async {
    await _pump(tester);
    expect(
      tester
          .widgetList<GallerySection>(find.byType(GallerySection))
          .map((section) => section.title),
      [
        _l10n.gallerySectionProgressBar,
        _l10n.gallerySectionMiniPlayer,
        _l10n.gallerySectionContinueCard,
        _l10n.gallerySectionResourceRow,
        _l10n.gallerySectionReaderPlayerBar,
      ],
    );
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(find.byType(ContinueCard), findsOneWidget);
    expect(find.byType(ReaderPlayerBar), findsOneWidget);
    expect(
      tester
          .widgetList<ResourceRow>(find.byType(ResourceRow))
          .map((row) => row.status),
      ResourceStatus.values.reversed,
    );
    // Two samples of its own, and one inside each player widget, card and
    // downloading row.
    expect(find.byType(ProgressBar), findsNWidgets(5));
  });

  testWidgets('play and pause toggle both players', (tester) async {
    await _pump(tester);
    expect(_main(IconName.pause), findsNWidgets(2));
    await tester.tap(_main(IconName.pause).first);
    await tester.pump();
    expect(_main(IconName.play), findsNWidgets(2));
  });
}
