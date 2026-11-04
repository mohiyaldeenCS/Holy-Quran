import 'package:flutter/material.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';

// `.qk-tabbar` `border-top: 1px solid var(--line)`, drawn under the strip
// instead of over it; the tokens give no width for a hairline.
const double _hairlineWidth = 1;

/// The marking of the unapproved test copy (D-159 (5), D-162 (4), D-164): an
/// [IntegrityAlert] with the copy's name as its title, on `surface` under a
/// `line` hairline, above the whole navigator and under the status bar.
class UnapprovedCopyBanner extends StatelessWidget {
  const UnapprovedCopyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      // Container adds the hairline to the padding, as CSS does.
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(
            // ignore: avoid_redundant_argument_values
            bottom: BorderSide(color: colors.line, width: _hairlineWidth),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.space4,
              vertical: AppSpacing.space2,
            ),
            // Above the navigator no Material sets a text style.
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodyMedium!,
              child: IntegrityAlert(
                title: AppLocalizations.of(context).unapprovedTestCopy,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
