import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';

/// The line shown after a deletion (`UD-07`): [message] and the word «تراجع»
/// as a text `Button`. The identity draws no such bar; it is a `surface` card
/// with the `line` border and `radius-button` of its cards, the card shadow,
/// and the `body` style. A screen reader hears it announced.
class UndoBar extends StatelessWidget {
  const UndoBar({required this.message, required this.onUndo, super.key});

  final String message;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(AppRadius.radiusButton),
          boxShadow: context.shadows.shadowCard,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.space4,
            end: AppSpacing.space2,
          ),
          child: Row(
            spacing: AppSpacing.space2,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(color: colors.ink),
                ),
              ),
              Button(
                label: AppLocalizations.of(context).undo,
                variant: ButtonVariant.text,
                onPressed: onUndo,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
