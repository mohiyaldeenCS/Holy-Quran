import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/ui/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:holyquran/ui/features/onboarding/view_models/setup_step.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import 'onboarding_fixture.dart';

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

  List<SetupStepKind> kinds(List<SetupStep> steps) => [
    for (final step in steps) step.kind,
  ];

  OnboardingViewModel open({List<CatalogueRecitation> recitations = const []}) {
    final viewModel = OnboardingViewModel(
      settings: settings,
      steps: setupSteps(settings, recitations: recitations),
      recitations: recitations,
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  test('with no Ready recitation it asks the display mode and the level '
      '(D-136 (3))', () {
    final steps = setupSteps(settings, recitations: const []);

    expect(kinds(steps), [SetupStepKind.displayMode, SetupStepKind.level]);
    expect(setupFinished(steps), isFalse);
  });

  test('with Ready recitations it asks the recitation last, offering each '
      '(D-127, D-136 (3))', () {
    for (final recitations in [
      [readyRecitation('synthetic-only', 'قارئ تجريبي')],
      twoReadyRecitations(),
    ]) {
      final viewModel = open(recitations: recitations);

      expect(kinds(setupSteps(settings, recitations: recitations)), [
        SetupStepKind.displayMode,
        SetupStepKind.level,
        SetupStepKind.recitation,
      ]);
      expect(viewModel.recitations, recitations);
    }
  });

  test('the level starts at «بسيط» and a choice is stored at once '
      '(LV-01, LV-02)', () async {
    final viewModel = open();

    expect(viewModel.level, UiLevel.simple);
    await viewModel.selectLevel(UiLevel.study);

    expect(settings.level, UiLevel.study);
    expect(settings.levelChosen, isFalse);
  });

  test('the pass is recorded once, when its last step is passed', () async {
    final viewModel = open(recitations: twoReadyRecitations());

    expect(viewModel.step?.kind, SetupStepKind.displayMode);
    expect(viewModel.onLastStep, isFalse);
    await viewModel.next();
    expect(viewModel.step?.kind, SetupStepKind.level);
    expect(settings.levelChosen, isFalse);
    await viewModel.next();
    expect(viewModel.step?.kind, SetupStepKind.recitation);
    expect(viewModel.onLastStep, isTrue);
    expect(settings.levelChosen, isFalse);

    await viewModel.next();

    expect(settings.levelChosen, isTrue);
    expect(viewModel.finished, isTrue);
    expect(viewModel.step, isNull);
  });

  test('with no Ready recitation the level step ends the setup', () async {
    final viewModel = open();

    await viewModel.next();
    expect(viewModel.step?.kind, SetupStepKind.level);
    expect(viewModel.onLastStep, isTrue);
    await viewModel.next();

    expect(settings.levelChosen, isTrue);
    expect(viewModel.finished, isTrue);
  });

  test('no recitation is chosen until the user chooses one', () {
    final [first, second] = twoReadyRecitations();
    final viewModel = open(recitations: [first, second]);
    var notified = 0;
    viewModel.addListener(() => notified++);

    expect(viewModel.recitation, isNull);
    viewModel.selectRecitation(second);

    expect(viewModel.recitation, same(second));
    expect(notified, 1);
  });

  test('a setup left midway starts again whole', () async {
    await open().next();

    expect(open().step?.kind, SetupStepKind.displayMode);
  });

  test('a finished setup is not asked again', () {
    settings.levelChosen = true;

    expect(open().finished, isTrue);
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
      steps: setupSteps(settings, recitations: const []),
    );

    final completing = viewModel.next();
    viewModel.dispose();

    expect(await completing, isA<Ok<void>>());
  });
}
