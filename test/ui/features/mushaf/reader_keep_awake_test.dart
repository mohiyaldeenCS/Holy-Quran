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

  test(
    'a recitation is held apart from reading, and counted the same',
    () async {
      final repository = FakeKeepAwakeRepository();
      final first = ReaderKeepAwake(repository);
      final second = ReaderKeepAwake(repository);
      first.shown(true);
      first.reciting(true);
      second.reciting(true);
      await Future<void>.delayed(Duration.zero);
      expect(repository.readerActive, isTrue);
      expect(repository.playerActive, isTrue);

      first.reciting(false);
      first.reciting(false);
      await Future<void>.delayed(Duration.zero);
      expect(repository.playerActive, isTrue);

      second.reciting(false);
      await Future<void>.delayed(Duration.zero);
      expect(repository.playerActive, isFalse);
      expect(repository.readerActive, isTrue);
    },
  );

  test('without a repository nothing happens', () {
    ReaderKeepAwake(null)
      ..shown(true)
      ..reciting(true)
      ..reciting(false)
      ..shown(false);
  });
}
