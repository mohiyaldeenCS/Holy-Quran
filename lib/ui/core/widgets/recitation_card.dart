import 'package:flutter/widgets.dart' hide Icon;

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/player_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/pressable.dart';
import 'package:holyquran/ui/core/widgets/star_outline.dart';

/// The reciter card of the Screens2 board's listen screen: the star badge,
/// the reciter over a line of details, and «تغيير» when [onChange] is
/// given. A null [reciter] or [details] is hidden, the badge with the
/// reciter.
class RecitationCard extends StatelessWidget {
  const RecitationCard({this.reciter, this.details, this.onChange, super.key});

  final String? reciter;
  final String? details;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final reciter = this.reciter;
    final details = this.details;
    final onChange = this.onChange;
    return Container(
      padding: PlayerMetrics.reciterCardPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.line),
        borderRadius: PlayerMetrics.reciterCardRadius,
      ),
      child: Row(
        spacing: AppSpacing.space3,
        children: [
          if (reciter != null)
            Container(
              width: AppSizes.targetMin,
              height: AppSizes.targetMin,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.player,
                shape: BoxShape.circle,
              ),
              child: StarOutline(
                size: PlayerMetrics.reciterStarSize,
                color: colors.playerAccent,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (reciter != null)
                  Text(
                    reciter,
                    style: AppTextStyles.bodyStrong.copyWith(color: colors.ink),
                  ),
                if (details != null && details.isNotEmpty)
                  Text(
                    details,
                    style: PlayerMetrics.smallText.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (onChange != null) _ChangeButton(onPressed: onChange),
        ],
      ),
    );
  }
}

/// «تغيير», a text action with a target-min hit area.
class _ChangeButton extends StatelessWidget {
  const _ChangeButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = AppLocalizations.of(context).playerChange;
    return Semantics(
      container: true,
      label: label,
      child: Pressable(
        onPressed: onPressed,
        focusRadius: PlayerMetrics.changeFocusRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.targetMin,
            minHeight: AppSizes.targetMin,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: ExcludeSemantics(
              child: Text(
                label,
                style: PlayerMetrics.changeText.copyWith(
                  color: context.colors.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
