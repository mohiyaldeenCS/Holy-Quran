import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/metrics/reader_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The mark of a reference-page boundary inside a surah-mode line (`RD-06`,
/// D-071): the number of the page that begins there, as the Mushaf board
/// writes the page number, centred in a marker's place so the text keeps
/// flowing. Read as «صفحة n».
final class PageMark extends StatelessWidget {
  const PageMark({required this.page, super.key});

  final int page;

  @override
  Widget build(BuildContext context) {
    final digits = arabicDigits(page);
    return Semantics(
      container: true,
      label: AppLocalizations.of(context).pageLabel(digits),
      child: ExcludeSemantics(
        child: Center(
          child: Text(
            digits,
            maxLines: 1,
            softWrap: false,
            style: AppTextStyles.secondary.copyWith(
              fontSize: ReaderMetrics.pageNumberSize,
              fontWeight: FontWeight.w600,
              color: context.colors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
