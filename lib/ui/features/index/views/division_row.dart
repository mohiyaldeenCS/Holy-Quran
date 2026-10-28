import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/edition_map.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/index_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/ui/features/index/view_models/index_view_model.dart';

/// A row of the juz or hizb index. The identity draws the surah row only
/// (`Screens2.dc.html`); this one takes its structure: the unit's number
/// inside a quarter star, its name, and the page. Under the name goes the
/// surah and ayah the unit starts at, in the place of the surah row's
/// meta line. The whole row is one button.
class DivisionRow extends StatelessWidget {
  const DivisionRow({required this.row, required this.onPressed, super.key});

  final DivisionIndexRow row;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    final number = arabicDigits(row.number);
    final title = switch (row.division) {
      Division.juz => l10n.juzLabel(number),
      Division.hizb => l10n.hizbLabel(number),
      _ => l10n.rubLabel,
    };
    // The star grows with the text and the digits are sized from it, as in
    // SurahListItem: a non-linear text scale would push them out of it.
    final box = MediaQuery.textScalerOf(context).scale(IndexMetrics.numberBox);
    final face = Padding(
      padding: IndexMetrics.rowInset(rub: row.isRub),
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.line)),
        ),
        padding: IndexMetrics.rowPadding,
        child: Row(
          spacing: IndexMetrics.rowGap,
          children: [
            SizedBox.square(
              dimension: box,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  StarOutline(size: box, stroke: IndexMetrics.numberStroke),
                  Text(
                    number,
                    maxLines: 1,
                    softWrap: false,
                    textScaler: TextScaler.noScaling,
                    style: IndexMetrics.numberStyleIn(
                      box,
                    ).copyWith(color: colors.accent),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: IndexMetrics.mainGap,
                children: [
                  Text(
                    title,
                    style: IndexMetrics.titleStyle.copyWith(color: colors.ink),
                  ),
                  SurahName(
                    row.surahName,
                    format: SurahNameFormat.withAyah,
                    ayah: row.address.ayah,
                    style: IndexMetrics.metaStyle.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: IndexMetrics.pageMinWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.surahListPage,
                    style: IndexMetrics.pageWordStyle.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  Text(
                    arabicDigits(row.page),
                    style: IndexMetrics.pageNumberStyle.copyWith(
                      color: colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: IndexMetrics.rowFocusRadius,
        child: face,
      ),
    );
  }
}
