import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/bookmark_repository.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/repositories/note_repository.dart';
import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:holyquran/domain/models/bookmark.dart';
import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/note.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/features/resources/views/resources_screen.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/flows/flow_driver.dart';
import '../../testing/flows/flow_rig.dart';
import '../../testing/flows/flow_server.dart';
import '../../testing/packs/synthetic_files.dart' show manifestFileName;
import '../../testing/packs/synthetic_tafsir_pack.dart';

void main() {
  final rig = FlowRig();

  T ok<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Failure(:final error) => fail('$error'),
  };

  rig.test('a pack is downloaded, verified and activated, deleted and '
      'downloaded again, and the bookmarks and notes are as they were', (
    tester,
    run,
  ) async {
    final marked = QuranAddress('hafs', 2, 5);
    final noted = QuranAddress('hafs', 1, 3);
    late List<Bookmark> bookmarksBefore;
    late List<Note> notesBefore;

    Future<void> expectUserDataUnchanged(
      BookmarkRepository bookmarks,
      NoteRepository notes,
    ) async {
      expect(ok(await bookmarks.list()), bookmarksBefore);
      expect(ok(await notes.list()), notesBefore);
    }

    String installedFile(String name) =>
        '${run.support.path}/packs/$flowTafsirId/1/$name';

    Future<void> expectInstalledAsServed() => real(tester, () async {
      for (final name in [manifestFileName, tafsirFileName]) {
        expect(
          await File(installedFile(name)).readAsBytes(),
          await File('${rig.tafsir.directory.path}/$name').readAsBytes(),
          reason: name,
        );
      }
      final checked = await const LocalPackRepository(
        files: PackFileService(),
        signatures: SignatureNotConfigured(),
      ).verify('${run.support.path}/packs/$flowTafsirId/1');
      expect(checked, isA<Ok<Object?>>());
    });

    Future<void> openResources(WidgetTester tester) async {
      await tapNamed(tester, flowL10n.tabMore);
      await tapNamed(tester, flowL10n.resourceManagerTitle);
      expect(find.byType(ResourcesScreen), findsOneWidget);
      await settle(
        tester,
        () => spokenNames(tester).any(
          (name) =>
              name.contains(flowL10n.resourceDownload) ||
              name.contains(flowL10n.resourceDelete),
        ),
      );
    }

    await run.session(tester, (session) async {
      final installs = session.read<PackInstallRepository>();
      final bookmarks = session.read<BookmarkRepository>();
      final notes = session.read<NoteRepository>();
      ok(await bookmarks.add(marked, BuiltinCategory.memorise.key));
      ok(await notes.add(noted, 'synthetic note body'));
      bookmarksBefore = ok(await bookmarks.list());
      notesBefore = ok(await notes.list());
      expect(bookmarksBefore, hasLength(1));
      expect(notesBefore, hasLength(1));

      await openResources(tester);
      expect(installs.installed, isEmpty);

      // The first copy of the file arrives damaged: it is refused and fetched
      // again, and only the whole one is activated.
      rig.server.corrupt['/$flowTafsirId/1/$tafsirFileName'] = 1;
      await tapNamed(
        tester,
        flowL10n.resourceDownload,
        done: () => installs.installed.isNotEmpty,
      );
      expect(
        [for (final pack in installs.installed) (pack.id, pack.version)],
        [(flowTafsirId, 1)],
      );
      expect(rig.server.gets('/$flowTafsirId/1/$tafsirFileName'), 2);
      await expectInstalledAsServed();
      await settle(
        tester,
        () => spokenNames(
          tester,
        ).any((name) => name.contains(flowL10n.resourceDelete)),
      );
      await expectUserDataUnchanged(bookmarks, notes);

      await tapNamed(
        tester,
        flowL10n.resourceDelete,
        done: () => installs.installed.isEmpty,
      );
      expect(Directory(installedFile('')).existsSync(), isFalse);
      await expectUserDataUnchanged(bookmarks, notes);

      await settle(
        tester,
        () => spokenNames(
          tester,
        ).any((name) => name.contains(flowL10n.resourceDownload)),
      );
      await tapNamed(
        tester,
        flowL10n.resourceDownload,
        done: () => installs.installed.isNotEmpty,
      );
      await expectInstalledAsServed();
      await expectUserDataUnchanged(bookmarks, notes);
    });

    // After a restart the pack is still installed and the user's data is the
    // same.
    await run.session(tester, (session) async {
      final installs = session.read<PackInstallRepository>();
      await real(tester, () => installs.started);
      expect([for (final pack in installs.installed) pack.id], [flowTafsirId]);
      await expectInstalledAsServed();
      await expectUserDataUnchanged(
        session.read<BookmarkRepository>(),
        session.read<NoteRepository>(),
      );
    });
  });
}
