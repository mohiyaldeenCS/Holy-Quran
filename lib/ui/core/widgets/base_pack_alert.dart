import 'package:flutter/widgets.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/base_pack_problem.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';

/// The [IntegrityAlert] for a base pack that serves no text, worded for its
/// [problem] (PRD §9.5, D-180).
class BasePackAlert extends StatelessWidget {
  const BasePackAlert(this.problem, {super.key});

  final BasePackProblem problem;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (problem) {
      BasePackProblem.missing => IntegrityAlert(
        title: l10n.integrityBaseMissingTitle,
        body: l10n.integrityBaseMissingBody,
      ),
      BasePackProblem.failed => IntegrityAlert(
        title: l10n.integrityBaseTitle,
        body: l10n.integrityBaseBody,
      ),
    };
  }
}
