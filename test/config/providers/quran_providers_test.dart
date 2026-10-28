import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/config/dependencies.dart';
import 'package:holyquran/config/providers/quran_providers.dart';
import 'package:holyquran/data/repositories/pack_integrity_repository.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/quran_text_repository.dart';
import 'package:holyquran/data/services/base_pack_service.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/quran_structure.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../testing/packs/synthetic_pack.dart';

const _id = 'synthetic-text';

/// Serves the files of [directory] as the bundled pack synthetic-text/1;
/// with no directory, the app bundles no pack.
final class _DirectoryBundle extends CachingAssetBundle {
  _DirectoryBundle(this.directory);

  final Directory? directory;

  @override
  Future<ByteData> load(String key) async {
    const prefix = 'assets/packs/$_id/1/';
    final file = File('${directory?.path}/${key.substring(prefix.length)}');
    if (directory == null || !key.startsWith(prefix) || !file.existsSync()) {
      throw FlutterError('Unable to load asset: "$key".');
    }
    return ByteData.sublistView(await file.readAsBytes());
  }
}

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('quran_providers'));
  tearDown(() => root.deleteSync(recursive: true));

  /// Sets up the Quran area over a bundle of the synthetic pack built with
  /// [fault], or over no bundle, and returns a context below its providers.
  Future<(BuildContext, BasePackService)> setUpArea(
    WidgetTester tester, {
    bool bundled = true,
    SyntheticFault? fault,
  }) async {
    final basePack = await tester.runAsync(() async {
      final pack = bundled
          ? await buildSyntheticPack(
              Directory('${root.path}/bundle'),
              fault: fault,
            )
          : null;
      return BasePackService(
        id: _id,
        version: 1,
        bundle: _DirectoryBundle(pack?.directory),
        supportDirectory: () async =>
            Directory('${root.path}/support').create(),
      );
    });
    final providers = await tester.runAsync(
      () => buildDependencies(
        areas: [
          (dependencies) => provideQuran(
            dependencies,
            basePack: basePack!,
            signatures: const SignatureNotConfigured(),
          ),
        ],
      ),
    );
    late BuildContext context;
    await tester.pumpWidget(
      MultiProvider(
        providers: providers!,
        child: Builder(
          builder: (inside) {
            context = inside;
            return const SizedBox();
          },
        ),
      ),
    );
    return (context, basePack!);
  }

  /// The area keeps the text pack open for the app's life. A test closes it
  /// before its folder is deleted, which Windows refuses for an open file.
  void closeTextAfterTest(BuildContext context) => addTearDown(
    (context.read<QuranTextRepository>() as PackQuranTextRepository).close,
  );

  testWidgets('a verified base pack provides its text and index', (
    tester,
  ) async {
    final (context, _) = await setUpArea(tester);
    closeTextAfterTest(context);

    expect(
      context.read<PackIntegrityRepository>().stateOf(_id),
      isA<IntegrityOk>(),
    );
    final index = context.read<QuranIndexRepository>();
    expect(index.surahCount, 3);
    expect(context.read<QuranStructure>(), same(index));
    final text = context.read<QuranTextRepository>();
    expect(
      await tester.runAsync(() => text.ayahText(QuranAddress('hafs', 2, 1))),
      isA<Ok<Object>>(),
    );
  });

  testWidgets('a surah that fails while reading fails the base pack', (
    tester,
  ) async {
    final (context, basePack) = await setUpArea(
      tester,
      fault: SyntheticFault.wrongSurahHash,
    );
    closeTextAfterTest(context);
    final integrity = context.read<PackIntegrityRepository>();
    final text = context.read<QuranTextRepository>();
    final index = context.read<QuranIndexRepository>();
    expect(integrity.stateOf(_id), isA<IntegrityOk>());
    expect(index.surahs, hasLength(3));

    final first = await tester.runAsync(
      () => text.ayahText(QuranAddress('hafs', 1, 1)),
    );

    expect(first, isA<Failure<Object>>());
    expect(
      integrity.stateOf(_id),
      isA<IntegrityFailed>().having(
        (state) => state.reason,
        'reason',
        isA<SurahHashMismatch>(),
      ),
    );
    expect(index.surahs, isEmpty);
    expect(
      await tester.runAsync(() => text.ayahText(QuranAddress('hafs', 2, 1))),
      isA<Failure<Object>>().having(
        (failure) => failure.error,
        'error',
        isA<PackDisabled>(),
      ),
    );
    // The check is forgotten without waiting; wait for it here.
    final remembered = await tester.runAsync(() async {
      final manifest = (await basePack.readBundled(manifestFileName))!;
      for (var tries = 0; tries < 100; tries++) {
        if (!await basePack.remembers(manifest)) return false;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      return true;
    });
    expect(remembered, isFalse);
  });

  testWidgets('a base pack that fails its check provides no text', (
    tester,
  ) async {
    final (context, _) = await setUpArea(
      tester,
      fault: SyntheticFault.flippedByte,
    );

    expect(
      context.read<PackIntegrityRepository>().stateOf(_id),
      isA<IntegrityFailed>(),
    );
    expect(
      () => context.read<QuranTextRepository>(),
      throwsA(isA<ProviderNotFoundException>()),
    );
    expect(
      () => context.read<QuranIndexRepository>(),
      throwsA(isA<ProviderNotFoundException>()),
    );
  });

  testWidgets('a base pack whose rows fail fails once and provides no text', (
    tester,
  ) async {
    final (context, _) = await setUpArea(
      tester,
      fault: SyntheticFault.wrongCounts,
    );
    final integrity = context.read<PackIntegrityRepository>();
    final events = await tester.runAsync(() async {
      final events = <PackIntegrityEvent>[];
      integrity.events.listen(events.add);
      await Future<void>.delayed(Duration.zero);
      return events;
    });

    expect(
      integrity.stateOf(_id),
      isA<IntegrityFailed>().having(
        (state) => state.reason,
        'reason',
        isA<PackInconsistent>(),
      ),
    );
    expect(
      [for (final e in events!) '${e.state}'.split(':').first],
      ['ok', 'failed'],
    );
    expect(
      () => context.read<QuranTextRepository>(),
      throwsA(isA<ProviderNotFoundException>()),
    );
  });

  testWidgets('a base pack the app does not bundle is missing', (tester) async {
    final (context, _) = await setUpArea(tester, bundled: false);

    expect(
      context.read<PackIntegrityRepository>().stateOf(_id),
      isA<IntegrityMissing>(),
    );
    expect(
      () => context.read<QuranIndexRepository>(),
      throwsA(isA<ProviderNotFoundException>()),
    );
  });

  test('no bundled base pack leaves the area empty', () async {
    expect(await buildDependencies(areas: [quranProviders]), isEmpty);
  });
}
