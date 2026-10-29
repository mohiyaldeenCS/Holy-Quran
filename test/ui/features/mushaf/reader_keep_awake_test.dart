import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/ui/features/mushaf/view_models/reader_keep_awake.dart';

import '../../../../testing/fakes/fake_keep_awake_repository.dart';

void main() {
  test(
    'readers stacked over each other keep it on until the last lets go',
    () async {
      final repository = FakeKeepAwakeRepository();
      final below = ReaderKeepAwake(repository);
      final above = ReaderKeepAwake(repository);

      below.shown(true);
      above.shown(true);
      below.shown(false);
      await Future<void>.delayed(Duration.zero);
      expect(repository.readerActive, isTrue);
      above.shown(false);
      await Future<void>.delayed(Duration.zero);
      expect(repository.readerActive, isFalse);
    },
  );

  test('a reader that lets go twice counts once', () async {
    final repository = FakeKeepAwakeRepository();
    final first = ReaderKeepAwake(repository);
    final second = ReaderKeepAwake(repository);
    first.shown(true);
    second.shown(true);
    first.shown(false);
    first.shown(false);
    await Future<void>.delayed(Duration.zero);
    expect(repository.readerActive, isTrue);
  });

  test('stand mode is counted apart from reading, across readers', () async {
    final repository = FakeKeepAwakeRepository(settingOn: false);
    final first = ReaderKeepAwake(repository);
    final second = ReaderKeepAwake(repository);
    first.standing(true);
    second.standing(true);
    first.standing(false);
    first.standing(false);
    await Future<void>.delayed(Duration.zero);
    expect(repository.standActive, isTrue);
    expect(repository.awake, isTrue);

    second.standing(false);
    await Future<void>.delayed(Duration.zero);
    expect(repository.standActive, isFalse);
    expect(repository.awake, isFalse);
  });

  test('without a repository nothing happens', () {
    ReaderKeepAwake(null)
      ..shown(true)
      ..standing(true)
      ..standing(false)
      ..shown(false);
  });
}
