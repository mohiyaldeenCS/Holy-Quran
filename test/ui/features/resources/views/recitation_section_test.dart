import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/catalogue_json.dart';
import 'package:holyquran/data/repositories/download_settings_repository.dart';
import 'package:holyquran/domain/models/catalogue.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/arabic_digits.dart';
import 'package:holyquran/ui/core/l10n/megabytes.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/level_switch.dart';
import 'package:holyquran/ui/core/widgets/progress_bar.dart';
import 'package:holyquran/ui/core/widgets/storage_bar.dart';
import 'package:holyquran/ui/core/widgets/switch.dart' as qk;
import 'package:holyquran/ui/features/resources/view_models/recitation_section_view_model.dart';
import 'package:holyquran/ui/features/resources/view_models/resources_view_model.dart';
import 'package:holyquran/ui/features/resources/views/resources_screen.dart';
import 'package:holyquran/ui/features/resources/views/sections/delete_recitation_sheet.dart';
import 'package:holyquran/ui/features/resources/views/sections/recitation_header.dart';
import 'package:holyquran/ui/features/resources/views/sections/scope_row.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../../testing/fakes/fake_quran_index_repository.dart';
import '../../../../../testing/fakes/fake_recitation_repository.dart';
import '../../../../../testing/golden.dart';
import '../recitation_downloads_fixtures.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

const _reciter = 'Synthetic reciter synthetic-listed';
const _style = 'Synthetic style';

late FakeCatalogueRepository _catalogue;
late FakePackInstallRepository _installs;
late FakePackIntegrityRepository _integrity;
late FakeRecitationDownloadRepository _downloads;
late DownloadSettingsRepository _settings;

/// The resource manager over the synthetic recitation, whose pack is
/// installed unless [installed] is false.
Future<RecitationSectionViewModel> _pump(
  WidgetTester tester, {
  bool installed = true,
  int packBytes = 0,
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(400, 2400),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _installs.installed = installed
      ? [installedRecitationPack(packBytes: packBytes)]
      : const [];
  final resources = ResourcesViewModel(
    catalogue: _catalogue,
    installs: _installs,
    integrity: _integrity,
    freeBytes: () async => 6000,
  );
  final recitations = RecitationSectionViewModel(
    recitations: FakeRecitationRepository(_catalogue.catalogue!.recitations),
    catalogue: _catalogue,
    installs: _installs,
    integrity: _integrity,
    downloads: _downloads,
    settings: _settings,
    index: FakeQuranIndexRepository.synthetic(),
    refreshEvery: Duration.zero,
  );
  addTearDown(resources.dispose);
  addTearDown(recitations.dispose);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: ResourcesScreen(
            viewModel: resources,
            recitations: recitations,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return recitations;
}

Finder _scope(String key) => find.byKey(ValueKey('$recitationId/$key'));

Finder _in(Finder scope, Finder finder) =>
    find.descendant(of: scope, matching: finder);

String _surahTitle(int number) => _l10n.surahTitle('Synthetic surah $number');

RecitationTarget _target(int quality, RecitationSelection selection) =>
    RecitationTarget(syntheticContents(), quality, selection);

/// Lets the count of the files on the device, which a change starts, end.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  setUp(() {
    _catalogue = FakeCatalogueRepository(syntheticCatalogue());
    _installs = FakePackInstallRepository();
    _integrity = FakePackIntegrityRepository();
    _downloads = FakeRecitationDownloadRepository();
    _settings = InMemoryDownloadSettingsRepository(
      qualities: {recitationId: 64},
    );
    addTearDown(_integrity.dispose);
  });

  testWidgets('names the category and the recitation by reciter and style', (
    tester,
  ) async {
    await _pump(tester, installed: false);

    expect(find.text(_l10n.resourceCategoryRecitations), findsOneWidget);
    expect(
      find.text([_reciter, _style].join(_l10n.dataSeparator)),
      findsOneWidget,
    );
    expect(find.text(_l10n.wifiOnly), findsOneWidget);
  });

  testWidgets('lists no recitation without a complete rights record', (
    tester,
  ) async {
    await _pump(tester, installed: false);

    expect(find.textContaining('rights-pending'), findsNothing);
  });

  testWidgets('offers the pack before anything else, with its size', (
    tester,
  ) async {
    await _pump(tester, installed: false);

    expect(find.byType(ScopeRow), findsNothing);
    final entry = _catalogue.catalogue!.pack(recitationPackId)!;
    expect(
      find.textContaining(megabytes(_l10n, entry.bytes)),
      findsAtLeastNWidgets(1),
    );
    await tester.tap(find.text(_l10n.resourceDownload).first);
    expect(_installs.calls, contains(('install', recitationPackId)));
  });

  testWidgets('shows the size still to download before a scope starts', (
    tester,
  ) async {
    await _pump(tester);

    expect(
      _in(
        _scope('64/surah-1'),
        find.text(_l10n.resourceAvailableMeta(megabytes(_l10n, 4 * fileBytes))),
      ),
      findsOneWidget,
    );
    expect(
      _in(
        _scope('64/all'),
        find.text(_l10n.resourceAvailableMeta(megabytes(_l10n, 8 * fileBytes))),
      ),
      findsOneWidget,
    );
    expect(find.text(_l10n.recitationDownloadWhole), findsOneWidget);
    expect(find.text(_surahTitle(2)), findsOneWidget);
    expect(_downloads.calls.where((c) => c.$1 == 'download'), isEmpty);
  });

  testWidgets('queues a surah, a juz and the whole from their buttons', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(
      _in(_scope('64/surah-2'), find.text(_l10n.resourceDownload)),
    );
    await tester.tap(_in(_scope('64/all'), find.text(_l10n.resourceDownload)));
    await tester.tap(find.text(_l10n.indexTabJuz));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.juzLabel(arabicDigits(2))), findsOneWidget);
    await tester.tap(
      _in(_scope('64/span-2:1-3:1'), find.text(_l10n.resourceDownload)),
    );

    expect(_downloads.calls.where((c) => c.$1 == 'download').map((c) => c.$2), [
      '$recitationId/64/surah-2',
      '$recitationId/64/all',
      '$recitationId/64/span-2:1-3:1',
    ]);
  });

  testWidgets('keeps Wi-Fi only on until it is turned off', (tester) async {
    await _pump(tester);
    expect(tester.widget<qk.Switch>(find.byType(qk.Switch)).value, isTrue);

    await tester.tap(find.text(_l10n.wifiOnly));
    await tester.pump();

    expect(tester.widget<qk.Switch>(find.byType(qk.Switch)).value, isFalse);
    expect(_settings.wifiOnly, isFalse);
  });

  testWidgets('chooses the quality when the catalogue offers several', (
    tester,
  ) async {
    await _pump(tester);
    final low = _l10n.recitationQualityKbps(arabicDigits(64));
    final high = _l10n.recitationQualityKbps(arabicDigits(128));
    expect(find.text(low), findsOneWidget);
    expect(find.text(high), findsOneWidget);

    await tester.tap(find.text(high));
    await tester.pumpAndSettle();
    await tester.tap(
      _in(_scope('128/surah-3'), find.text(_l10n.resourceDownload)),
    );

    expect(
      _downloads.calls.where((c) => c.$1 == 'download').single.$2,
      '$recitationId/128/surah-3',
    );
  });

  testWidgets('offers no quality choice when there is one quality', (
    tester,
  ) async {
    final json = syntheticCatalogueJson();
    ((json['recitations']! as List<Object?>).first!
        as Map<String, Object?>)['qualities'] = [
      64,
    ];
    _catalogue = FakeCatalogueRepository(
      (parseCatalogue(catalogueBytes(json)) as Ok<Catalogue>).value,
    );
    await _pump(tester);

    expect(
      find.text(_l10n.recitationQualityKbps(arabicDigits(64))),
      findsNothing,
    );
    expect(find.text(_l10n.qualityLabel), findsNothing);
  });

  testWidgets('shows progress and a stop button while a scope downloads', (
    tester,
  ) async {
    final recitations = await _pump(tester);
    _downloads.jobs = [
      jobFor(
        _target(64, const RecitationSurah(1)),
        downloadingBytes(1000000, 2000000),
      ),
    ];
    await tester.pump();

    final row = _scope('64/surah-1');
    expect(_in(row, find.byType(ProgressBar)), findsOneWidget);
    expect(
      _in(row, find.text(_l10n.percentValue(arabicDigits(50)))),
      findsOneWidget,
    );
    expect(_in(row, find.text(_l10n.resourceDownload)), findsNothing);

    await tester.tap(_in(row, find.text(_l10n.resourceStop)));
    expect(_downloads.calls, contains(('cancel', '$recitationId/64/surah-1')));
    expect(recitations.blocks.single.surahs.first.progress, 0.5);
  });

  testWidgets('says it waits for Wi-Fi', (tester) async {
    await _pump(tester);
    _downloads.jobs = [
      jobFor(
        _target(64, const RecitationSurah(1)),
        const RecitationWaitingForNetwork(wifiOnly: true),
      ),
    ];
    await tester.pump();

    expect(
      _in(_scope('64/surah-1'), find.text(_l10n.waitingForWifi)),
      findsOneWidget,
    );
  });

  testWidgets(
    'a downloaded scope can be deleted and the files are counted again',
    (tester) async {
      await _pump(tester);
      _downloads.arrive({for (var a = 1; a <= 3; a++) ayahPath(64, 2, a)});
      await _settle(tester);

      final row = _scope('64/surah-2');
      expect(
        _in(
          row,
          find.text(
            _l10n.resourceDownloadedMeta(megabytes(_l10n, 3 * fileBytes)),
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(_in(row, find.text(_l10n.resourceDelete)));
      await tester.pumpAndSettle();
      expect(
        _downloads.calls,
        contains(('delete', '$recitationId/64/surah-2')),
      );
      expect(_in(row, find.text(_l10n.resourceDownload)), findsOneWidget);
    },
  );

  testWidgets(
    'a download that stopped keeps what arrived and says what is left',
    (tester) async {
      await _pump(tester);
      _downloads.arrive({ayahPath(64, 1, 1), ayahPath(64, 1, 2)});
      _downloads.jobs = [
        jobFor(
          _target(64, const RecitationSurah(1)),
          const RecitationDownloadFailed(
            RecitationNoSpace('k', neededBytes: 1, freeBytes: 0),
          ),
        ),
      ];
      await _settle(tester);

      final row = _scope('64/surah-1');
      expect(
        _in(
          row,
          find.text(
            _l10n.resourceAvailableMeta(megabytes(_l10n, 2 * fileBytes)),
          ),
        ),
        findsOneWidget,
      );
      expect(_in(row, find.text(_l10n.lowSpace)), findsOneWidget);
      expect(_in(row, find.text(_l10n.resourceResume)), findsOneWidget);
      expect(_in(row, find.text(_l10n.resourceDownload)), findsNothing);
    },
  );

  testWidgets('names a file that failed its check and offers it again', (
    tester,
  ) async {
    await _pump(tester);
    _downloads.jobs = [
      jobFor(
        _target(64, const RecitationSurah(3)),
        const RecitationDownloadFailed(RecitationFileRejected('k', 'p')),
      ),
    ];
    await tester.pump();

    final row = _scope('64/surah-3');
    expect(_in(row, find.byType(IntegrityAlert)), findsOneWidget);
    await tester.tap(_in(row, find.text(_l10n.resourceRedownload)));
    expect(
      _downloads.calls.where((c) => c.$1 == 'download').single.$2,
      '$recitationId/64/surah-3',
    );
  });

  testWidgets('a failed connection says so', (tester) async {
    await _pump(tester);
    _downloads.jobs = [
      jobFor(
        _target(64, const RecitationSurah(3)),
        const RecitationDownloadFailed(RecitationFileNotFetched('k', 'p')),
      ),
    ];
    await tester.pump();

    expect(
      _in(_scope('64/surah-3'), find.text(_l10n.connectionFailed)),
      findsOneWidget,
    );
  });

  testWidgets('a file that could not be saved says so', (tester) async {
    await _pump(tester);
    _downloads.jobs = [
      jobFor(
        _target(64, const RecitationSurah(3)),
        const RecitationDownloadFailed(RecitationStoreFailed('k', 'synthetic')),
      ),
    ];
    await tester.pump();

    final row = _scope('64/surah-3');
    expect(_in(row, find.text(_l10n.downloadNotSaved)), findsOneWidget);
    expect(_in(row, find.text(_l10n.connectionFailed)), findsNothing);
  });

  testWidgets('says a Wi-Fi only choice was not saved, and shows the stored '
      'one', (tester) async {
    _settings = FlakyDownloadSettings(qualities: {recitationId: 64});
    await _pump(tester);
    expect(find.text(_l10n.changeNotSaved), findsNothing);

    await tester.tap(find.text(_l10n.wifiOnly));
    await _settle(tester);

    expect(find.text(_l10n.changeNotSaved), findsOneWidget);
    expect(find.text(_l10n.downloadNotSaved), findsNothing);
    expect(tester.widget<qk.Switch>(find.byType(qk.Switch)).value, isTrue);
  });

  testWidgets('says a quality choice was not saved, and shows the stored '
      'one', (tester) async {
    _settings = FlakyDownloadSettings(qualities: {recitationId: 64});
    await _pump(tester);

    await tester.tap(find.text(_l10n.recitationQualityKbps(arabicDigits(128))));
    await _settle(tester);

    expect(find.text(_l10n.changeNotSaved), findsOneWidget);
    expect(find.text(_l10n.downloadNotSaved), findsNothing);
    expect(_scope('64/surah-3'), findsOneWidget);
    expect(_scope('128/surah-3'), findsNothing);
  });

  testWidgets('a refused start is shown on its row', (tester) async {
    await _pump(tester);
    _downloads.downloads = (target) => Failure(
      RecitationUrlRefused(target.key, Uri.parse('http://example.invalid/')),
    );

    await tester.tap(
      _in(_scope('64/surah-3'), find.text(_l10n.resourceDownload)),
    );
    await tester.pumpAndSettle();

    expect(
      _in(_scope('64/surah-3'), find.text(_l10n.connectionFailed)),
      findsOneWidget,
    );
  });

  group('the recitation as a whole', () {
    Finder inHeader(Finder finder) =>
        find.descendant(of: find.byType(RecitationHeader), matching: finder);

    Set<String> everyFileAt64() => {
      for (final MapEntry(key: surah, value: ayat) in ayatOfSurah.entries)
        for (var a = 1; a <= ayat; a++) ayahPath(64, surah, a),
    };

    testWidgets('is available, partly downloaded, then downloaded', (
      tester,
    ) async {
      await _pump(tester);
      expect(inHeader(find.textContaining(_l10n.resourceAvailable)), findsOne);

      _downloads.arrive({ayahPath(64, 1, 1)});
      await _settle(tester);
      expect(inHeader(find.textContaining(_l10n.recitationPartial)), findsOne);
      expect(
        inHeader(find.textContaining(_l10n.resourceDownloaded)),
        findsNothing,
      );

      _downloads.arrive(everyFileAt64());
      await _settle(tester);
      expect(
        inHeader(find.textContaining(_l10n.resourceDownloaded)),
        findsOneWidget,
      );
    });

    testWidgets('is deleted only after the user confirms, stating the size', (
      tester,
    ) async {
      await _pump(tester, packBytes: 700000);
      _downloads.arrive({ayahPath(64, 1, 1), ayahPath(128, 1, 1)});
      await _settle(tester);

      await tester.tap(inHeader(find.text(_l10n.resourceDelete)));
      await tester.pumpAndSettle();

      expect(find.byType(DeleteRecitationSheet), findsOneWidget);
      expect(find.text(_l10n.deleteRecitationTitle), findsOneWidget);
      expect(
        find.text(_l10n.downloadSize(megabytes(_l10n, 2 * fileBytes + 700000))),
        findsOneWidget,
      );
      expect(
        _downloads.calls,
        isNot(contains(('deleteAudio', recitationPackId))),
      );

      await tester.tap(find.text(_l10n.resourceDelete).last);
      await tester.pumpAndSettle();

      expect(_downloads.calls, contains(('deleteAudio', recitationPackId)));
      expect(_installs.calls, contains(('delete', recitationPackId)));
    });

    testWidgets('is kept when the user leaves the confirmation', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(inHeader(find.text(_l10n.resourceDelete)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n.resourceCancel));
      await tester.pumpAndSettle();

      expect(find.byType(DeleteRecitationSheet), findsNothing);
      expect(
        _downloads.calls,
        isNot(contains(('deleteAudio', recitationPackId))),
      );
      expect(_installs.calls, isEmpty);
    });

    testWidgets('cannot be deleted while a job of it runs', (tester) async {
      await _pump(tester);
      _downloads.arrive(everyFileAt64());
      await _settle(tester);
      expect(find.text(_l10n.resourceDelete), findsWidgets);

      _downloads.jobs = [
        jobFor(_target(64, const RecitationSurah(1)), const RecitationQueued()),
      ];
      await tester.pump();

      expect(inHeader(find.text(_l10n.resourceDelete)), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ScopeRow),
          matching: find.text(_l10n.resourceDelete),
        ),
        findsNothing,
      );
    });

    testWidgets('can still be deleted after a download failed', (tester) async {
      await _pump(tester);
      _downloads.arrive(everyFileAt64());
      _downloads.jobs = [
        jobFor(
          _target(64, const RecitationSurah(1)),
          const RecitationDownloadFailed(RecitationFileNotFetched('k', 'p')),
        ),
      ];
      await _settle(tester);

      expect(inHeader(find.text(_l10n.resourceDelete)), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ScopeRow),
          matching: find.text(_l10n.resourceDelete),
        ),
        findsWidgets,
      );
    });

    testWidgets('shows the space its recitations use', (tester) async {
      await _pump(tester);

      final bar = find.byWidgetPredicate(
        (widget) =>
            widget is StorageBar &&
            widget.label == _l10n.resourceCategoryRecitations,
      );
      expect(bar, findsOneWidget);
    });
  });

  group('a scope row', () {
    testWidgets('names its buttons by the scope for a screen reader', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester);
        _downloads.arrive({ayahPath(64, 2, 1)});
        _downloads.jobs = [
          jobFor(
            _target(64, const RecitationSurah(1)),
            downloadingBytes(1000000, 2000000),
          ),
        ];
        await _settle(tester);

        expect(
          find.bySemanticsLabel(_l10n.resourceDownloadNamed(_surahTitle(3))),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(_l10n.resourceStopNamed(_surahTitle(1))),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(_l10n.resourceResumeNamed(_surahTitle(2))),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('says it is queued, without a percent', (tester) async {
      await _pump(tester);
      _downloads.jobs = [
        jobFor(_target(64, const RecitationSurah(1)), const RecitationQueued()),
      ];
      await tester.pump();

      final row = _scope('64/surah-1');
      expect(_in(row, find.text(_l10n.resourceQueued)), findsOneWidget);
      expect(_in(row, find.textContaining('٪')), findsNothing);
      expect(_in(row, find.text(_l10n.resourceStop)), findsOneWidget);
    });

    testWidgets('says it waits for the network when Wi-Fi is not required', (
      tester,
    ) async {
      await _pump(tester);
      _downloads.jobs = [
        jobFor(
          _target(64, const RecitationSurah(1)),
          const RecitationWaitingForNetwork(wifiOnly: false),
        ),
      ];
      await tester.pump();

      final row = _scope('64/surah-1');
      expect(_in(row, find.text(_l10n.waitingForNetwork)), findsOneWidget);
      expect(_in(row, find.textContaining('٪')), findsNothing);
    });

    testWidgets('resumes a scope that is partly on the device', (tester) async {
      await _pump(tester);
      _downloads.arrive({ayahPath(64, 1, 1)});
      await _settle(tester);

      await tester.tap(
        _in(_scope('64/surah-1'), find.text(_l10n.resourceResume)),
      );

      expect(
        _downloads.calls.where((c) => c.$1 == 'download').single.$2,
        '$recitationId/64/surah-1',
      );
    });
  });

  group('the choices', () {
    testWidgets('the qualities and the lists are segmented controls', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.byType(LevelSwitch), findsNWidgets(2));
      expect(find.bySemanticsLabel(_l10n.qualityLabel), findsWidgets);
      expect(find.bySemanticsLabel(_l10n.recitationScopeLabel), findsWidgets);
    });
  });

  group('the design system checklist', () {
    testWidgets('every control is labelled with a hit area of at least 48', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester);
        _downloads.jobs = [
          jobFor(
            _target(64, const RecitationSurah(1)),
            downloadingBytes(1000000, 2000000),
          ),
        ];
        await tester.pump();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('a progress bar is announced with the scope and its percent', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester);
        _downloads.jobs = [
          jobFor(
            _target(64, const RecitationSurah(1)),
            downloadingBytes(1000000, 2000000),
          ),
        ];
        await tester.pump();

        expect(
          find.bySemanticsLabel(_l10n.resourceDownloading(_surahTitle(1))),
          findsOneWidget,
        );
      } finally {
        semantics.dispose();
      }
    });

    for (final theme in ReadingTheme.values) {
      testWidgets('lays out at 200% text in ${theme.name} without overflow', (
        tester,
      ) async {
        await _pump(tester, theme: theme, textScale: 2);
        _downloads.jobs = [
          jobFor(
            _target(64, const RecitationSurah(1)),
            downloadingBytes(1000000, 2000000),
          ),
        ];
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(ScopeRow), findsWidgets);
      });
    }
  });
}
