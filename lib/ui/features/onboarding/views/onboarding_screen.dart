import 'package:flutter/material.dart' hide Button;
import 'package:go_router/go_router.dart';

import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/routing/routes.dart';
import 'package:holyquran/ui/core/metrics/settings_metrics.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/lockup.dart';
import 'package:holyquran/ui/core/widgets/radio_row.dart';
import 'package:holyquran/ui/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:holyquran/ui/features/onboarding/view_models/setup_step.dart';
import 'package:provider/provider.dart';

/// The first-run setup under the `Lockup` (O-17, D-127): one step at a time,
/// its name, its prompt, its choices and the button that passes it. The
/// identity does not draw it; it is laid out as the settings screen from the
/// identity's components.
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
    final l10n = AppLocalizations.of(context);
    final viewModel = context.watch<OnboardingViewModel>();
    final step = viewModel.step;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: SettingsMetrics.header,
              child: Center(
                child: Semantics(header: true, child: const Lockup()),
              ),
            ),
            Expanded(
              child: ListView(
                padding: SettingsMetrics.content,
                children: [
                  if (step != null) ...[
                    _StepHeading(
                      name: l10n.stepName(step.kind),
                      prompt: l10n.stepPrompt(step.kind),
                    ),
                    const SizedBox(height: SettingsMetrics.contentGap),
                    switch (step.kind) {
                      SetupStepKind.displayMode => RadioRow(
                        selected: true,
                        onTap: () {},
                        child: Text(
                          l10n.displayModeSurah,
                          style: RadioRow.labelStyle,
                        ),
                      ),
                      SetupStepKind.level => _LevelChoice(viewModel),
                      SetupStepKind.recitation => _RecitationChoice(viewModel),
                    },
                    const SizedBox(height: SettingsMetrics.contentGap),
                    Button(
                      label: viewModel.onLastStep
                          ? l10n.setupFinish
                          : l10n.setupContinue,
                      onPressed: viewModel.next,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.name, required this.prompt});

  final String name;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            name,
            style: AppTextStyles.sectionTitle.copyWith(color: colors.ink),
          ),
        ),
        const SizedBox(height: SettingsMetrics.contentGap),
        Text(
          prompt,
          style: AppTextStyles.secondary.copyWith(color: colors.inkMuted),
        ),
      ],
    );
  }
}

class _LevelChoice extends StatelessWidget {
  const _LevelChoice(this.viewModel);

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

// With no recitation in the catalogue the step keeps its name, prompt and
// button, and shows no row.
class _RecitationChoice extends StatelessWidget {
  const _RecitationChoice(this.viewModel);

  final OnboardingViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final recitation = viewModel.recitation;
    if (recitation == null) return const SizedBox.shrink();
    return RadioRow(
      selected: true,
      onTap: () {},
      child: Text(
        recitation.recitation.reciter,
        style: RadioRow.labelStyle,
      ),
    );
  }
}

extension on AppLocalizations {
  String stepName(SetupStepKind kind) => switch (kind) {
    SetupStepKind.displayMode => setupStepDisplayMode,
    SetupStepKind.level => setupStepLevel,
    SetupStepKind.recitation => setupStepRecitation,
  };

  String stepPrompt(SetupStepKind kind) => switch (kind) {
    SetupStepKind.displayMode => setupDisplayModePrompt,
    SetupStepKind.level => setupLevelPrompt,
    SetupStepKind.recitation => setupRecitationPrompt,
  };
}
