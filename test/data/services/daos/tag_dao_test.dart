import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/services/daos/tag_dao.dart';
import 'package:holyquran/data/services/user_database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late UserDatabase db;
  late TagDao dao;

  setUp(() {
    db = UserDatabase(NativeDatabase.memory());
    dao = TagDao(db);
  });
  tearDown(() => db.close());

  test('named makes a tag once per exact name, stored as given', () async {
    final alpha = await dao.named(' tag-alpha', at: 10);
    final again = await dao.named(' tag-alpha', at: 20);
    final other = await dao.named('tag-alpha', at: 30);

    expect(alpha.name, ' tag-alpha');
    expect(alpha.createdAt, 10);
    expect(again, alpha);
    expect(other.id, isNot(alpha.id));
    expect(await dao.live(), unorderedEquals([alpha, other]));
    expect(await dao.byId(alpha.id), alpha);
  });

  test(
    'liveNamed lists live namesakes oldest first; named takes the first',
    () async {
      for (final (id, at) in [('id-b', 20), ('id-c', 10), ('id-a', 20)]) {
        await db
            .into(db.tag)
            .insert(
              TagRow(
                id: id,
                updatedAt: at,
                deleted: false,
                name: 'tag-alpha',
                createdAt: at,
              ),
            );
      }
      await dao.markDeleted('id-c', at: 30);

      expect((await dao.liveNamed('tag-alpha')).map((t) => t.id), [
        'id-a',
        'id-b',
      ]);
      expect((await dao.named('tag-alpha', at: 40)).id, 'id-a');
      expect(await dao.liveNamed('tag-beta'), isEmpty);
    },
  );

  test('named makes a new tag when the old one is deleted', () async {
    final alpha = await dao.named('tag-alpha', at: 10);
    await dao.markDeleted(alpha.id, at: 20);

    expect((await dao.named('tag-alpha', at: 30)).id, isNot(alpha.id));
  });

  test('rename changes a live tag only', () async {
    final alpha = await dao.named('tag-alpha', at: 10);

    expect(await dao.rename(alpha.id, 'tag-gamma', at: 20), isTrue);
    expect((await dao.byId(alpha.id))!.name, 'tag-gamma');
    expect((await dao.byId(alpha.id))!.updatedAt, 20);
    expect(await dao.rename('absent', 'x', at: 20), isFalse);
    await dao.markDeleted(alpha.id, at: 30);
    expect(await dao.rename(alpha.id, 'x', at: 40), isFalse);
  });

  test('markDeleted keeps a tombstone that revive clears', () async {
    final alpha = await dao.named('tag-alpha', at: 10);

    expect(await dao.markDeleted(alpha.id, at: 20), isTrue);
    expect(await dao.markDeleted(alpha.id, at: 25), isFalse);
    expect(await dao.live(), isEmpty);
    expect((await dao.byId(alpha.id))!.deleted, isTrue);

    expect(await dao.revive(alpha.id, at: 30), isTrue);
    expect(await dao.revive(alpha.id, at: 35), isFalse);
    expect(await dao.live(), hasLength(1));
    expect((await dao.byId(alpha.id))!.updatedAt, 30);
  });
}
