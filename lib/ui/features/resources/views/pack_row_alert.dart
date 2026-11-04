import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/metrics/resources_metrics.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';

/// The alert under a pack's row: a pack that failed a check offers to be
/// downloaded again, and one whose download did not arrive says so.
class PackRowAlertView extends StatelessWidget {
  const PackRowAlertView({
    required this.alert,
    required this.onRedownload,
    super.key,
  });

  final PackRowAlert alert;
  final VoidCallback onRedownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: resourcesRowFootPadding,
      child: switch (alert) {
        // Its title and body await their wording (PHASE1.md, Appendix C);
        // the action names what it does.
        PackRowAlert.integrity => IntegrityAlert(
          action: (label: l10n.resourceRedownload, onPressed: onRedownload),
        ),
        PackRowAlert.connection => IntegrityAlert(title: l10n.connectionFailed),
      },
    );
  }
}
