import 'package:flutter/widgets.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

/// The actions of the stand-in toolbar. PRD §7.4 names five: play, bookmark,
/// study, copy and share. Copy and share are left out: their icons are among
/// the eight of D-051 not yet drawn, and no ARB string names them.
enum AyahToolbarAction { playFromHere, bookmark, study }

/// A stand-in for the ayah toolbar that a marker tap or a long press opens
/// (PRD §7.4, M0.4-4): the identity's [IconButton]s with `AyahRow`'s labels,
/// on a `surface` card. The real toolbar is M1.6's.
final class AyahToolbarStandIn extends StatelessWidget {
  const AyahToolbarStandIn({required this.onAction, super.key});

  final ValueChanged<AyahToolbarAction> onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(AppRadius.radiusCard),
          boxShadow: context.shadows.shadowCard,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.space1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.space1,
            children: [
              for (final (action, icon, label) in [
                (
                  AyahToolbarAction.playFromHere,
                  IconName.play,
                  l10n.ayahRowPlayFromHere,
                ),
                (
                  AyahToolbarAction.bookmark,
                  IconName.bookmark,
                  l10n.ayahRowBookmark,
                ),
                (AyahToolbarAction.study, IconName.study, l10n.ayahRowStudy),
              ])
                IconButton(
                  icon: icon,
                  label: label,
                  onPressed: () => onAction(action),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
