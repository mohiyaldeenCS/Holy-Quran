import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

/// The mark of a reference-page boundary inside a surah-mode line (`RD-06`,
/// D-071): the number of the page that begins there, as the boards write a
/// page number (`secondary` at weight 600 in `accent`: `Mushaf.dc.html`,
/// «رقم الصفحة»; the reader's footer on `Screens.dc.html`), centred in a
/// marker's place so the text keeps flowing, and shrunk rather than cut if it
/// does not fit. Read as «صفحة n».
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            digits,
            maxLines: 1,
            softWrap: false,
            style: AppTextStyles.secondary.copyWith(
              fontWeight: FontWeight.w600,
              color: context.colors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
