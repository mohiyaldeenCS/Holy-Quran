import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/copy_sheet.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/share_card.dart';

/// The share sheet (SH-02, SH-03): the three designs, the card that will be
/// shared, and «مشاركة». When the ayah fits no card, [card] is null and the
/// sheet says so and offers to copy it instead.
///
/// The identity does not draw this sheet: it takes the copy sheet's frame
/// and the identity's components. It has no title and no "save the image"
/// action, which have no wording yet (D-052; docs/plans/PHASE1.md,
/// Appendix C).
class ShareCardSheet extends StatelessWidget {
  const ShareCardSheet({
    required this.design,
    required this.onDesignSelected,
    required this.card,
    required this.onShare,
    required this.onCopy,
    super.key,
  });

  final ShareCardDesign design;
  final ValueChanged<ShareCardDesign> onDesignSelected;

  /// The card at its fitted size, or null when the ayah is too long.
  final ShareCard? card;

  /// Shares [card]; null while sharing.
  final VoidCallback? onShare;

  /// Opens the copy sheet.
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final card = this.card;
    return CopySheetFrame(
      children: [
        LevelSwitch(
          options: [
            for (final design in ShareCardDesign.values) _name(design, l10n),
          ],
          selectedIndex: design.index,
          onChanged: (index) => onDesignSelected(ShareCardDesign.values[index]),
          semanticLabel: l10n.gallerySectionShareCard,
        ),
        if (card != null) ...[
          Center(
            child: FittedBox(fit: BoxFit.scaleDown, child: card),
          ),
          CopySheetFrame.action(
            Button(label: l10n.toolbarShare, onPressed: onShare),
          ),
        ] else ...[
          Text(
            l10n.shareTooLong,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(color: context.colors.ink),
          ),
          CopySheetFrame.action(
            Button(label: l10n.copyAction, onPressed: onCopy),
          ),
        ],
      ],
    );
  }
}

String _name(ShareCardDesign design, AppLocalizations l10n) => switch (design) {
  ShareCardDesign.emerald => l10n.shareDesignEmerald,
  ShareCardDesign.paper => l10n.shareDesignPaper,
  ShareCardDesign.night => l10n.shareDesignNight,
};
