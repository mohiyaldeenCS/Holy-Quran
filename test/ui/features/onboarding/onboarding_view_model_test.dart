import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/recitation.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/ui/features/onboarding/view_models/onboarding_view_model.dart';
import 'package:holyquran/ui/features/onboarding/view_models/setup_step.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../testing/fakes/fake_app_settings_repository.dart';
import '../../../../testing/fakes/fake_recitation_repository.dart';

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

CatalogueRecitation _recitation(String id) => CatalogueRecitation(
  recitation: Recitation(
    id: id,
    reciter: 'نص تجريبي',
    riwaya: 'hafs',
    style: 'Synthetic style',
    unit: RecitationUnit.ayah,
    hasWordTiming: false,
    rightsComplete: true,
  ),
  qualities: [64],
  packId: 'synthetic-audio',
);

void main() {
  late FakeAppSettingsRepository settings;

  setUp(() => settings = FakeAppSettingsRepository());

  OnboardingViewModel open({FakeRecitationRepository? recitations}) {
    final viewModel = OnboardingViewModel(
      settings: settings,
      steps: setupSteps(settings),
      recitations: recitations,
    );
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  test('asks display mode, level and recitation, in that order (D-127)', () {
    final steps = setupSteps(settings);

    expect(
      [for (final step in steps) step.kind],
      [
        SetupStepKind.displayMode,
        SetupStepKind.level,
        SetupStepKind.recitation,
      ],
    );
    expect(setupFinished(steps), isFalse);
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
    final viewModel = open();

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
    expect(setupFinished(setupSteps(settings)), isTrue);
  });

  test('a setup left midway starts again whole', () async {
    await open().next();

    expect(open().step?.kind, SetupStepKind.displayMode);
  });

  test('a finished setup is not asked again', () {
    settings.levelChosen = true;

    expect(open().finished, isTrue);
  });

  test('the recitation choice is the catalogue first one, null with none', () {
    final recitations = FakeRecitationRepository();
    final viewModel = open(recitations: recitations);
    var notified = 0;
    viewModel.addListener(() => notified++);

    expect(viewModel.recitation, isNull);
    recitations.recitations = [
      _recitation('synthetic-first'),
      _recitation('synthetic-second'),
    ];

    expect(viewModel.recitation?.recitation.id, 'synthetic-first');
    expect(notified, 1);
    expect(open().recitation, isNull);
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
