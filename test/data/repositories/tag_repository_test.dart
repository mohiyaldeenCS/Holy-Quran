import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/tag_repository.dart';
import 'package:holyquran/data/services/daos/tag_dao.dart';
import 'package:holyquran/data/services/user_database.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/utils/result.dart';

final class _FailingDao extends TagDao {
  _FailingDao(super.attachedDatabase);

  static const _failure = FormatException('synthetic failure');

  @override
  Future<List<TagRow>> live() async => throw _failure;

  @override
  Future<TagRow> named(String name, {required int at}) async => throw _failure;

  @override
  Future<bool> rename(String id, String name, {required int at}) async =>
      throw _failure;

  @override
  Future<bool> markDeleted(String id, {required int at}) async =>
      throw _failure;

  @override
  Future<TagRow?> byId(String id) async => throw _failure;

  @override
  Future<List<TagRow>> liveNamed(String name) async => throw _failure;
}

T _value<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw error,
};

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late int clock;
  late LocalTagRepository tags;
  late int notified;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    clock = 1000;
    tags = LocalTagRepository(TagDao(db), now: () => clock);
    notified = 0;
    tags.addListener(() => notified++);
  });
  tearDown(() => db.close());

  test('creates tags once per name, listed by name, and notifies', () async {
    final beta = _value(await tags.create('tag-beta'));
    final alpha = _value(await tags.create('tag-alpha'));
    final again = _value(await tags.create('tag-beta'));

    expect(beta.name, 'tag-beta');
    expect(beta.createdAt, DateTime.utc(1970, 1, 1, 0, 0, 1));
    expect(again, beta);
    expect(_value(await tags.tags()), [alpha, beta]);
    expect(notified, 2, reason: 'an existing tag is not a change');
  });

  test('keeps a name as typed', () async {
    final spaced = _value(await tags.create(' tag-alpha '));

    expect(spaced.name, ' tag-alpha ');
    expect(_value(await tags.create('tag-alpha')).id, isNot(spaced.id));
  });

  test('refuses an empty name', () async {
    final tag = _value(await tags.create('tag-alpha'));
    notified = 0;

    expect((await tags.create('') as Failure).error, isA<FormatException>());
    expect(
      (await tags.rename(tag.id, '') as Failure).error,
      isA<FormatException>(),
    );
    expect(notified, 0);
    expect(_value(await tags.tags()), [tag]);
  });

  test('renames a live tag, also to its own name', () async {
    final tag = _value(await tags.create('tag-alpha'));

    expect(await tags.rename(tag.id, 'tag-alpha'), isA<Ok<void>>());
    expect(await tags.rename(tag.id, 'tag-gamma'), isA<Ok<void>>());
    expect(_value(await tags.tags()).single.name, 'tag-gamma');
    expect(
      (await tags.rename('absent', 'x') as Failure).error,
      isA<ItemNotFound>(),
    );
  });

  test('refuses to rename onto a name another live tag has', () async {
    final alpha = _value(await tags.create('tag-alpha'));
    final beta = _value(await tags.create('tag-beta'));
    notified = 0;

    final result = await tags.rename(beta.id, 'tag-alpha');

    expect((result as Failure).error, isA<TagNameTaken>());
    expect(notified, 0);
    expect(_value(await tags.tags()), [alpha, beta]);
  });

  test('refuses to restore a tag whose name was taken since', () async {
    final old = _value(await tags.create('x'));
    await tags.delete(old.id);
    final current = _value(await tags.create('x'));
    notified = 0;

    final result = await tags.restore(old.id);

    expect((result as Failure).error, isA<TagNameTaken>());
    expect(notified, 0);
    expect(_value(await tags.tags()), [current]);
    expect((await TagDao(db).byId(old.id))!.deleted, isTrue);
  });

  test('restoring a live tag changes nothing', () async {
    final tag = _value(await tags.create('tag-alpha'));
    notified = 0;

    expect(await tags.restore(tag.id), isA<Ok<void>>());
    expect(notified, 0);
  });

  test('a deletion is undone within the window, then stays', () async {
    final kept = _value(await tags.create('tag-kept'));
    final lost = _value(await tags.create('tag-lost'));
    clock = 5000;
    await tags.delete(kept.id);
    await tags.delete(lost.id);

    expect(_value(await tags.tags()), isEmpty);
    expect((await tags.delete(kept.id) as Failure).error, isA<ItemNotFound>());
    expect(
      (await tags.rename(kept.id, 'x') as Failure).error,
      isA<ItemNotFound>(),
    );

    clock = 5000 + undoWindow.inMilliseconds;
    expect(await tags.restore(kept.id), isA<Ok<void>>());
    expect(await tags.restore(kept.id), isA<Ok<void>>());
    clock++;
    final late = await tags.restore(lost.id);

    expect((late as Failure).error, isA<UndoExpired>());
    expect(_value(await tags.tags()), [kept]);
    expect((await TagDao(db).byId(lost.id))!.deleted, isTrue);
    expect(
      (await tags.restore('absent') as Failure).error,
      isA<ItemNotFound>(),
    );
  });

  test('a failing database returns Failures and does not notify', () async {
    final failing = LocalTagRepository(_FailingDao(db));
    var heard = 0;
    failing.addListener(() => heard++);

    expect(await failing.tags(), isA<Failure<List<UserTag>>>());
    expect(await failing.create('x'), isA<Failure<UserTag>>());
    expect(await failing.rename('a', 'x'), isA<Failure<void>>());
    expect(await failing.delete('a'), isA<Failure<void>>());
    expect(await failing.restore('a'), isA<Failure<void>>());
    expect(heard, 0);
  });

  test('tags survive closing and reopening a file database', () async {
    final directory = await Directory.systemTemp.createTemp('tag_test');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/${UserDatabase.fileName}');

    final first = UserDatabase(NativeDatabase(file));
    final tag = _value(await LocalTagRepository(TagDao(first)).create('tag-a'));
    await first.close();

    final second = UserDatabase(NativeDatabase(file));
    addTearDown(second.close);
    expect(_value(await LocalTagRepository(TagDao(second)).tags()), [tag]);
  });
}
