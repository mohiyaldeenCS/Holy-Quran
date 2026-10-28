import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/ui/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:holyquran/ui/features/onboarding/view_models/setup_step.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';

/// A step another task will bring, such as the display mode.
final class _Step implements SetupStep {
  @override
  bool done = false;

  @override
  SetupStepKind get kind => SetupStepKind.level;

  @override
  Future<Result<void>> complete() async {
    done = true;
    return const Ok(null);
  }
}

void main() {
  late FakeAppSettingsRepository settings;

  setUp(() => settings = FakeAppSettingsRepository());

  test('Phase 1 asks the level, the only step with its wording', () {
    final steps = setupSteps(settings);

    expect([for (final step in steps) step.kind], [SetupStepKind.level]);
    expect(setupFinished(steps), isFalse);
  });

  test('the level step is done once the level is chosen', () async {
    final viewModel = OnboardingViewModel(
      settings: settings,
      steps: setupSteps(settings),
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.step, isA<LevelStep>());
    await viewModel.selectLevel(UiLevel.study);
    expect(settings.level, UiLevel.study);
    expect(settings.levelChosen, isFalse);

    await viewModel.next();

    expect(settings.levelChosen, isTrue);
    expect(viewModel.finished, isTrue);
    expect(viewModel.step, isNull);
    expect(setupFinished(setupSteps(settings)), isTrue);
  });

  test('every step is shown in the order given, then the setup finishes '
      '(D-127)', () async {
    final first = _Step();
    final last = _Step();
    final steps = [first, LevelStep(settings), last];
    final viewModel = OnboardingViewModel(settings: settings, steps: steps);
    addTearDown(viewModel.dispose);

    expect(viewModel.step, same(first));
    await viewModel.next();
    expect(first.done, isTrue);
    expect(viewModel.step, isA<LevelStep>());
    await viewModel.next();
    expect(viewModel.step, same(last));
    await viewModel.next();

    expect(viewModel.finished, isTrue);
    expect(setupFinished(steps), isTrue);
  });

  test('a step already done is not asked again', () {
    settings.levelChosen = true;
    final viewModel = OnboardingViewModel(
      settings: settings,
      steps: setupSteps(settings),
    );
    addTearDown(viewModel.dispose);

    expect(viewModel.finished, isTrue);
  });

  test('a second next while a step completes moves on once', () async {
    final first = _Step();
    final viewModel = OnboardingViewModel(
      settings: settings,
      steps: [first, _Step()],
    );
    addTearDown(viewModel.dispose);

    await Future.wait([viewModel.next(), viewModel.next()]);

    expect(viewModel.finished, isFalse);
    expect(viewModel.step, isNot(same(first)));
  });

  test('closing the setup while a step completes raises nothing', () async {
    final viewModel = OnboardingViewModel(
      settings: settings,
      steps: setupSteps(settings),
    );

    final completing = viewModel.next();
    viewModel.dispose();

    expect(await completing, isA<Ok<void>>());
  });
}
