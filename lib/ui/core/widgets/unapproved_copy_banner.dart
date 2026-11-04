import 'package:flutter/material.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';

/// The marking of the unapproved test copy (D-159 (5), D-162 (4), D-164): an
/// [IntegrityAlert] with the copy's name as its title, on `surface` under a
/// `line` hairline, above the whole navigator and under the status bar.
class UnapprovedCopyBanner extends StatelessWidget {
  const UnapprovedCopyBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // `.qk-tabbar` draws `1px solid var(--line)` on its top edge; here it is
    // mirrored to the bottom edge, with the default 1 px width as tab_bar.dart.
    // Container adds the hairline to the padding, as CSS does.
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.line)),
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
    );
  }
}
