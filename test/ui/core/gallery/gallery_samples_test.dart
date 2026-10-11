import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/gallery_samples.dart';
import 'package:holyquran/ui/core/gallery/gallery_section.dart';
import 'package:holyquran/ui/core/theme/ramps.g.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

void main() {
  test('each sample is its synthetic ARB string, unchanged', () {
    final samples = {
      GallerySamples.text(_l10n): _l10n.sampleText,
      GallerySamples.longText(_l10n): _l10n.sampleLongText,
      GallerySamples.word(_l10n): _l10n.sampleWord,
      GallerySamples.surahName(_l10n): _l10n.sampleSurahName,
    };
    for (final MapEntry(key: sample, value: string) in samples.entries) {
      expect(sample, PackText.fromPack(string));
    }
    expect(samples.values.toSet(), hasLength(samples.length));
  });

  testWidgets('a section titles its samples with a header in ink-muted', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        GallerySection(
          title: _l10n.gallerySectionAyahRow,
          child: galleryRow([
            const GalleryBackdrop(
              color: Ramps.emerald700,
              child: SizedBox.square(dimension: 10),
            ),
          ]),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text(_l10n.gallerySectionAyahRow));
    expect(title.style!.color, AppColors.paper.inkMuted);
    expect(
      tester.getSemantics(find.text(_l10n.gallerySectionAyahRow)),
      isSemantics(label: _l10n.gallerySectionAyahRow, isHeader: true),
    );
    final row = tester.widget<Wrap>(find.byType(Wrap));
    expect(row.spacing, AppSpacing.space3);
    expect(row.crossAxisAlignment, WrapCrossAlignment.center);
    final box =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byType(GalleryBackdrop),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(box.borderRadius, BorderRadius.circular(AppRadius.radiusCard));
    handle.dispose();
  });
}
