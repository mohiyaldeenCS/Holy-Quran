import 'package:flutter/widgets.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon_paths.g.dart';

/// The steps from ayah to ayah (`TF-03`): previous on the reading start side,
/// next beyond it, pointing the way the reading goes. A step with nowhere to
/// go is disabled, and says so to a screen reader.
class TafsirSteps extends StatelessWidget {
  const TafsirSteps({
    required this.previous,
    required this.next,
    required this.onStep,
    super.key,
  });

  final QuranAddress? previous;
  final QuranAddress? next;
  final ValueChanged<QuranAddress> onStep;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final previous = this.previous;
    final next = this.next;
    return Row(
      spacing: AppSpacing.space3,
      children: [
        Expanded(
          child: Button(
            label: l10n.playerPreviousAyah,
            icon: IconName.previous,
            variant: ButtonVariant.tonal,
            onPressed: previous == null ? null : () => onStep(previous),
          ),
        ),
        Expanded(
          child: Button(
            label: l10n.playerNextAyah,
            icon: IconName.next,
            variant: ButtonVariant.tonal,
            onPressed: next == null ? null : () => onStep(next),
          ),
        ),
      ],
    );
  }
}
