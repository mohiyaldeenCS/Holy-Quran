import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_block_state.dart';
import 'package:holyquran/ui/features/resources/view_models/recitation_section_view_model.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../../testing/fakes/fake_recitation_repository.dart';
import '../recitation_downloads_fixtures.dart';

late FakePackInstallRepository _installs;
late FakeRecitationDownloadRepository _downloads;
late FakePackIntegrityRepository _integrity;
late DownloadSettingsRepository _settings;

Future<RecitationSectionViewModel> _viewModel({
  bool installed = true,
  bool withIndex = true,

  /// The quality the user chose before; none leaves the default.
  int? quality = 64,
  bool wifiOnly = true,
  bool basmala = false,
  int packBytes = 0,
  DownloadSettingsRepository? settings,
}) async {
  final catalogue = syntheticCatalogue();
  _installs = FakePackInstallRepository(
    installed: installed
        ? [installedRecitationPack(packBytes: packBytes)]
        : const [],
  );
  _downloads = FakeRecitationDownloadRepository(
    contents: syntheticContents(withBasmala: basmala),
  );
  _integrity = FakePackIntegrityRepository();
  _settings =
      settings ??
      InMemoryDownloadSettingsRepository(
        wifiOnly: wifiOnly,
        qualities: {recitationId: ?quality},
      );
  final viewModel = RecitationSectionViewModel(
    recitations: FakeRecitationRepository(catalogue.recitations),
    catalogue: FakeCatalogueRepository(catalogue),
    installs: _installs,
    integrity: _integrity,
    downloads: _downloads,
    settings: _settings,
    index: withIndex ? FakeQuranIndexRepository.synthetic() : null,
    refreshEvery: Duration.zero,
  );
  addTearDown(viewModel.dispose);
  addTearDown(_integrity.dispose);
  await pumpEventQueue();
  return viewModel;
}

RecitationBlockState _block(RecitationSectionViewModel viewModel) =>
    viewModel.blocks.single;

ScopeRowState _surah(RecitationBlockState block, int number) =>
    block.surahs.singleWhere((row) => row.number == number);

RecitationTarget _target(int quality, RecitationSelection selection) =>
    RecitationTarget(syntheticContents(), quality, selection);

/// Lets a count of the files on the device, started by a change, finish.
Future<void> _settle() async {
  await pumpEventQueue();
  await Future<void>.delayed(Duration.zero);
  await pumpEventQueue();
}

void main() {
  group('the listing', () {
    test('holds the recitations with a complete rights record', () async {
      final viewModel = await _viewModel();

      expect(viewModel.blocks.map((b) => b.id), [recitationId]);
    });

    test('shows no scope until the pack is installed (AU-13)', () async {
      final viewModel = await _viewModel(installed: false);

      expect(_block(viewModel).ready, isFalse);
      expect(_downloads.calls, isEmpty);
    });

    test(
      'offers the whole, each surah and each juz once the pack is read',
      () async {
        final block = _block(await _viewModel());

        expect(block.ready, isTrue);
        expect(block.surahs.map((r) => r.number), [1, 2, 3]);
        expect(block.juz.map((r) => r.number), [1, 2]);
      },
    );

    test('offers the whole alone without an index', () async {
      final block = _block(await _viewModel(withIndex: false));

      expect(block.whole, isNotNull);
      expect(block.surahs, isEmpty);
      expect(block.juz, isEmpty);
    });

    test(
      'does not read a pack again for a change that is not its own',
      () async {
        final viewModel = await _viewModel();
        _installs.jobs = const [];
        _downloads.jobs = const [];
        await pumpEventQueue();

        expect(_downloads.calls.where((c) => c.$1 == 'contents'), hasLength(1));
        expect(viewModel.blocks, hasLength(1));
      },
    );

    test('reads a pack that does not verify once for each version', () async {
      final viewModel = await _viewModel(installed: false);
      _downloads.contentsAnswer = Failure(Exception('does not verify'));
      _installs.installed = [installedRecitationPack()];
      await pumpEventQueue();
      _installs.jobs = const [];
      _downloads.jobs = const [];
      await pumpEventQueue();

      expect(_downloads.calls.where((c) => c.$1 == 'contents'), hasLength(1));
      expect(_block(viewModel).ready, isFalse);
    });
  });

  group('the size before starting (AU-13)', () {
    test('is the bytes of the files of each scope', () async {
      final block = _block(await _viewModel());

      expect(block.whole!.totalBytes, 8 * fileBytes);
      expect(_surah(block, 1).totalBytes, 4 * fileBytes);
      expect(_surah(block, 3).totalBytes, fileBytes);
      expect(block.juz.map((r) => r.totalBytes), [
        4 * fileBytes,
        4 * fileBytes,
      ]);
      expect(block.whole!.missingBytes, block.whole!.totalBytes);
    });

    test('is what is still to fetch when part is on the device', () async {
      final viewModel = await _viewModel();
      _downloads.arrive({ayahPath(64, 1, 1), ayahPath(64, 1, 2)});
      await _settle();

      final block = _block(viewModel);
      final surah = _surah(block, 1);
      expect(surah.missingBytes, 2 * fileBytes);
      expect(surah.partial, isTrue);
      expect(surah.status, ScopeStatus.available);
      expect(block.whole!.missingBytes, 6 * fileBytes);
    });

    test(
      'is none, and the scope downloaded, once all of it is there',
      () async {
        final viewModel = await _viewModel();
        _downloads.arrive({for (var a = 1; a <= 4; a++) ayahPath(64, 1, a)});
        await _settle();

        final block = _block(viewModel);
        expect(_surah(block, 1).status, ScopeStatus.downloaded);
        expect(block.juz.first.status, ScopeStatus.downloaded);
        expect(block.juz.last.status, ScopeStatus.available);
      },
    );
  });

  group('how much of the recitation is here (AU-13)', () {
    test('none of it, some of it, then all of it', () async {
      final viewModel = await _viewModel();
      expect(_block(viewModel).status, RecitationStatus.available);

      _downloads.arrive({ayahPath(64, 1, 1)});
      await _settle();
      expect(_block(viewModel).status, RecitationStatus.partial);

      _downloads.arrive({
        for (final MapEntry(key: surah, value: ayat) in ayatOfSurah.entries)
          for (var a = 1; a <= ayat; a++) ayahPath(64, surah, a),
      });
      await _settle();
      expect(_block(viewModel).status, RecitationStatus.downloaded);
    });

    test('is judged at the quality chosen', () async {
      final viewModel = await _viewModel();
      _downloads.arrive({
        for (final MapEntry(key: surah, value: ayat) in ayatOfSurah.entries)
          for (var a = 1; a <= ayat; a++) ayahPath(64, surah, a),
      });
      await _settle();

      viewModel.selectQuality(recitationId, 128);
      await _settle();

      expect(_block(viewModel).status, RecitationStatus.available);
    });

    test('a scope needs the reciter\'s own files too', () async {
      final viewModel = await _viewModel(basmala: true);
      _downloads.arrive({for (var a = 1; a <= 4; a++) ayahPath(64, 1, a)});
      await _settle();

      final before = _surah(_block(viewModel), 1);
      expect(before.status, ScopeStatus.available);
      expect(before.missingBytes, fileBytes);

      _downloads.arrive({basmalaPath(64)});
      await _settle();
      expect(_surah(_block(viewModel), 1).status, ScopeStatus.downloaded);
      expect(_surah(_block(viewModel), 2).status, ScopeStatus.available);
    });

    test('a failed job does not stop the recitation being deleted', () async {
      final viewModel = await _viewModel();

      _downloads.jobs = [
        jobFor(
          _target(64, const RecitationSurah(1)),
          const RecitationDownloadFailed(RecitationFileNotFetched('k', 'p')),
        ),
      ];

      expect(_block(viewModel).hasJob, isFalse);

      _downloads.jobs = [
        jobFor(
          _target(64, const RecitationSurah(1)),
          const RecitationDownloadFailed(RecitationFileNotFetched('k', 'p')),
        ),
        jobFor(_target(64, const RecitationSurah(2)), const RecitationQueued()),
      ];

      expect(_block(viewModel).hasJob, isTrue);
    });

    test('a job of its pack is told, so that it cannot be deleted', () async {
      final viewModel = await _viewModel();
      expect(_block(viewModel).hasJob, isFalse);

      _downloads.jobs = [
        jobFor(_target(64, const RecitationSurah(1)), const RecitationQueued()),
      ];

      expect(_block(viewModel).hasJob, isTrue);
      expect(_surah(_block(viewModel), 1).status, ScopeStatus.queued);
    });

    test('the space used is the audio at every quality', () async {
      final viewModel = await _viewModel();
      expect(viewModel.usedBytes, 0);

      _downloads.arrive({ayahPath(64, 1, 1), ayahPath(128, 1, 1)});
      await _settle();

      expect(viewModel.usedBytes, 2 * fileBytes);
    });

    test(
      'the space used leaves out a recitation that is not installed',
      () async {
        final viewModel = await _viewModel(installed: false);
        _downloads.arrive({ayahPath(64, 1, 1)});
        await _settle();

        expect(viewModel.usedBytes, 0);
      },
    );
  });

  group('jobs queued', () {
    test('per surah, per juz and for the whole', () async {
      final viewModel = await _viewModel();
      final block = _block(viewModel);

      viewModel
        ..download(recitationId, _surah(block, 2))
        ..download(recitationId, block.juz.last)
        ..download(recitationId, block.whole!);
      await pumpEventQueue();

      expect(
        _downloads.calls.where((c) => c.$1 == 'download').map((c) => c.$2),
        [
          '$recitationId/64/surah-2',
          '$recitationId/64/span-2:1-3:1',
          '$recitationId/64/all',
        ],
      );
    });

    test('follow Wi-Fi only, which is on to begin with', () async {
      final viewModel = await _viewModel();
      expect(viewModel.wifiOnly, isTrue);
      viewModel.download(recitationId, _block(viewModel).whole!);
      viewModel.wifiOnly = false;
      viewModel.download(recitationId, _block(viewModel).whole!);
      await pumpEventQueue();

      expect(_downloads.wifiOnlyOf, [true, false]);
    });

    test('keep Wi-Fi only in the settings', () async {
      final viewModel = await _viewModel();

      viewModel.wifiOnly = false;

      expect(_settings.wifiOnly, isFalse);
      expect(viewModel.wifiOnly, isFalse);
    });

    test(
      'show the stored Wi-Fi only, and say so when it was not saved',
      () async {
        final flaky = FlakyDownloadSettings(qualities: {recitationId: 64});
        final viewModel = await _viewModel(settings: flaky);
        expect(viewModel.settingNotSaved, isFalse);

        viewModel.wifiOnly = false;
        await _settle();

        expect(viewModel.wifiOnly, isTrue);
        expect(viewModel.settingNotSaved, isTrue);

        flaky.failing = false;
        viewModel.wifiOnly = false;
        await _settle();

        expect(viewModel.wifiOnly, isFalse);
        expect(viewModel.settingNotSaved, isFalse);
      },
    );

    test('install the pack with the same choice', () async {
      final viewModel = await _viewModel(installed: false);
      viewModel.wifiOnly = false;

      viewModel.downloadPack(recitationId);

      expect(_installs.calls, [('install', recitationPackId)]);
    });

    test('show a refused download as a failure of its row', () async {
      final viewModel = await _viewModel();
      _downloads.downloads = (target, _) => Failure(
        RecitationUrlRefused(target.key, Uri.parse('http://example.invalid/')),
      );

      viewModel.download(recitationId, _block(viewModel).whole!);
      await pumpEventQueue();

      expect(_block(viewModel).whole!.failure, isA<RecitationUrlRefused>());
    });
  });

  group('progress, stop and delete', () {
    test('a running job shows its progress and a held one its wait', () async {
      final viewModel = await _viewModel();

      _downloads.jobs = [
        jobFor(
          _target(64, const RecitationSurah(1)),
          downloadingBytes(1000000, 2000000),
        ),
        jobFor(
          _target(64, const RecitationSurah(2)),
          const RecitationWaitingForNetwork(wifiOnly: true),
        ),
      ];

      final block = _block(viewModel);
      expect(_surah(block, 1).status, ScopeStatus.downloading);
      expect(_surah(block, 1).progress, 0.5);
      expect(_surah(block, 2).status, ScopeStatus.waiting);
      expect(_surah(block, 2).waitingForWifi, isTrue);
    });

    test('a failed job shows its failure beside the state it leaves', () async {
      final viewModel = await _viewModel();
      _downloads.jobs = [
        jobFor(
          _target(64, const RecitationSurah(1)),
          const RecitationDownloadFailed(
            RecitationNoSpace('k', neededBytes: 1, freeBytes: 0),
          ),
        ),
      ];

      final row = _surah(_block(viewModel), 1);
      expect(row.failure, isA<RecitationNoSpace>());
      expect(row.status, ScopeStatus.available);
    });

    test('stop cancels the job by its key', () async {
      final viewModel = await _viewModel();

      viewModel.stop(_surah(_block(viewModel), 1));

      expect(
        _downloads.calls,
        contains(('cancel', '$recitationId/64/surah-1')),
      );
    });

    test(
      'delete removes the files of the scope and counts them again',
      () async {
        final viewModel = await _viewModel();
        _downloads.arrive({for (var a = 1; a <= 4; a++) ayahPath(64, 1, a)});
        await _settle();

        await viewModel.delete(recitationId, _surah(_block(viewModel), 1));

        expect(
          _downloads.calls,
          contains(('delete', '$recitationId/64/surah-1')),
        );
        expect(_surah(_block(viewModel), 1).status, ScopeStatus.available);
      },
    );

    test(
      'deleting the recitation removes all its audio, then its pack',
      () async {
        final viewModel = await _viewModel();

        await viewModel.deleteRecitation(recitationId);

        expect(_downloads.calls, contains(('deleteAudio', recitationPackId)));
        expect(_installs.calls, [('delete', recitationPackId)]);
      },
    );

    test('the size to delete counts every quality and the pack on the '
        'device, not the latest of the catalogue', () async {
      final viewModel = await _viewModel(packBytes: 12345);
      _downloads.arrive({ayahPath(64, 1, 1), ayahPath(128, 1, 1)});

      final size = await viewModel.sizeToDelete(recitationId);

      final pack = syntheticCatalogue().pack(recitationPackId)!;
      expect(pack.bytes, isNot(12345));
      await _settle();
      expect(size, 2 * fileBytes + 12345);
      expect(size, viewModel.usedBytes);
    });

    test('a delete that fails is shown on its row', () async {
      final viewModel = await _viewModel();
      _downloads.arrive({for (var a = 1; a <= 4; a++) ayahPath(64, 1, a)});
      await _settle();
      _downloads.deletes = (_) =>
          const Failure(RecitationStoreFailed('k', 'synthetic'));

      await viewModel.delete(recitationId, _surah(_block(viewModel), 1));

      expect(
        _surah(_block(viewModel), 1).failure,
        isA<RecitationStoreFailed>(),
      );
    });
  });

  group('the quality (AU-14)', () {
    test('lists the qualities the catalogue offers', () async {
      final block = _block(await _viewModel());

      expect(block.qualities, [64, 128]);
      expect(block.choosesQuality, isTrue);
    });

    test(
      'is the highest the recitation offers until the user chooses',
      () async {
        final viewModel = await _viewModel(quality: null);

        expect(_block(viewModel).quality, 128);
        viewModel.download(recitationId, _block(viewModel).whole!);
        await pumpEventQueue();
        expect(
          _downloads.calls.where((c) => c.$1 == 'download').single.$2,
          '$recitationId/128/all',
        );
      },
    );

    test('keeps the choice in the settings, and reads it back', () async {
      final viewModel = await _viewModel(quality: null);

      viewModel.selectQuality(recitationId, 64);
      await pumpEventQueue();

      expect(_settings.qualityOf(recitationId), 64);
      expect(_block(viewModel).quality, 64);
      final later = RecitationSectionViewModel(
        recitations: FakeRecitationRepository(syntheticCatalogue().recitations),
        catalogue: FakeCatalogueRepository(syntheticCatalogue()),
        installs: _installs,
        integrity: _integrity,
        downloads: _downloads,
        settings: _settings,
      );
      addTearDown(later.dispose);
      await pumpEventQueue();
      expect(later.blocks.single.quality, 64);
    });

    test(
      'goes back to the stored quality when the choice is not saved',
      () async {
        final flaky = FlakyDownloadSettings(qualities: {recitationId: 64});
        final viewModel = await _viewModel(settings: flaky);
        _downloads.arrive({ayahPath(128, 3, 1)});

        viewModel.selectQuality(recitationId, 128);
        await _settle();

        expect(_block(viewModel).quality, 64);
        expect(_surah(_block(viewModel), 3).status, ScopeStatus.available);
        expect(viewModel.settingNotSaved, isTrue);
      },
    );

    test('ignores a stored quality the catalogue no longer lists', () async {
      final viewModel = await _viewModel(quality: 320);

      expect(_block(viewModel).quality, 128);
    });

    test(
      'choosing another downloads, counts and deletes at that quality',
      () async {
        final viewModel = await _viewModel();
        _downloads.arrive({ayahPath(128, 3, 1)});

        viewModel.selectQuality(recitationId, 128);
        await pumpEventQueue();
        final block = _block(viewModel);

        expect(block.quality, 128);
        expect(_surah(block, 3).status, ScopeStatus.downloaded);
        expect(_surah(block, 1).status, ScopeStatus.available);
        viewModel.download(recitationId, _surah(block, 1));
        await pumpEventQueue();
        expect(
          _downloads.calls.where((c) => c.$1 == 'download').single.$2,
          '$recitationId/128/surah-1',
        );
      },
    );

    test('a quality that the catalogue does not list is not chosen', () async {
      final viewModel = await _viewModel();

      viewModel.selectQuality(recitationId, 320);
      await pumpEventQueue();

      expect(_block(viewModel).quality, 64);
    });
  });
}
