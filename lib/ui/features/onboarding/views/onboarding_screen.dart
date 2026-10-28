import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/settings_metrics.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/lockup.dart';
import 'package:holyquran/ui/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:holyquran/ui/features/onboarding/view_models/setup_step.dart';
import 'package:provider/provider.dart';

/// The first-run setup under the `Lockup` (O-17), an extension laid out as
/// the settings screen. The step names, each step's prompt and the continue
/// button wait for their wording (PHASE1.md, Appendix B and C), so they are
/// not shown and the start-up redirect stays off.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingViewModel _viewModel = context
      .read<OnboardingViewModel>();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_leaveWhenFinished);
    WidgetsBinding.instance.addPostFrameCallback((_) => _leaveWhenFinished());
  }

  @override
  void dispose() {
    _viewModel.removeListener(_leaveWhenFinished);
    super.dispose();
  }

  void _leaveWhenFinished() {
    if (mounted && _viewModel.finished) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final step = viewModel.step;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: SettingsMetrics.header,
              child: Center(child: Lockup()),
            ),
            Expanded(
              child: ListView(
                padding: SettingsMetrics.content,
                children: [
                  if (step != null)
                    switch (step.kind) {
                      SetupStepKind.level => _LevelStep(viewModel),
                    },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelStep extends StatelessWidget {
  const _LevelStep(this.viewModel);

  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LevelSwitch(
      options: [
        for (final level in UiLevel.values)
          switch (level) {
            UiLevel.simple => l10n.levelSimple,
            UiLevel.medium => l10n.levelMedium,
            UiLevel.study => l10n.levelStudy,
          },
      ],
      selectedIndex: viewModel.level.index,
      onChanged: (index) => viewModel.selectLevel(UiLevel.values[index]),
      semanticLabel: l10n.levelLabel,
    );
  }
}
