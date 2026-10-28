import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/models/catalogue_json.dart';
import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/resource_state.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/l10n/megabytes.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';
import 'package:holyquran/ui/features/resources/views/pack_row.dart';
import 'package:holyquran/utils/result.dart';

import '../../../../../testing/fakes/fake_catalogue_repository.dart';
import '../../../../../testing/golden.dart';
import '../resources_fixtures.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

/// The synthetic first-use tafsir with its [source], [changes] and the
/// [bytes] of its one file replaced, when given.
CatalogueEntry _entry({String? source, String? changes, int? bytes}) {
  final json = syntheticCatalogueJson();
  final packs = [
    for (final pack
        in (json['packs']! as List<Object?>).cast<Map<String, Object?>>())
      if (pack['id'] == firstUseId)
        {
          ...pack,
          'source': ?source,
          'changes': ?changes,
          if (bytes != null)
            'files': [
              {
                ...(pack['files']! as List).single as Map<String, Object?>,
                'bytes': bytes,
              },
            ],
        }
      else
        pack,
  ];
  return switch (parseCatalogue(catalogueBytes({...json, 'packs': packs}))) {
    Ok(:final value) => value.pack(firstUseId)!,
    Failure(:final error) => throw StateError('$error'),
  };
}

Future<void> _pump(WidgetTester tester, PackRowState row) async {
  tester.view
    ..physicalSize = const Size(400, 600)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      ReadingTheme.paper,
      PackRow(
        row: row,
        onDownload: () {},
        onDelete: () {},
        onRedownload: () {},
      ),
    ),
  );
}

PackRowState _row(CatalogueEntry entry, ResourceState state) => PackRowState(
  Resource(entry: entry, state: state, failure: null),
  integrityFailed: false,
);

String _line(List<String> parts) => parts.join(_l10n.dataSeparator);

void main() {
  testWidgets('available: state and size, then source, then version', (
    tester,
  ) async {
    final entry = _entry(source: 'نص تجريبي  للمصدر ', bytes: 4200000);
    await _pump(tester, _row(entry, const ResourceAvailable()));
    expect(megabytes(_l10n, 4200000), '٤٫٢ م.ب');
    expect(
      find.text(
        _line([
          _l10n.resourceAvailableMeta(megabytes(_l10n, 4200000)),
          'نص تجريبي  للمصدر ',
          '٢',
        ]),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an update adds its description last, unchanged', (tester) async {
    final entry = _entry(changes: ' نص تجريبي للتغيير');
    await _pump(
      tester,
      _row(
        entry,
        const ResourceUpdateAvailable(installedVersion: 1, version: 2),
      ),
    );
    expect(
      find.text(
        _line([
          _l10n.resourceDownloadedMeta(megabytes(_l10n, entry.bytes)),
          entry.source,
          '٢',
          ' نص تجريبي للتغيير',
        ]),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the description of an update is not shown otherwise', (
    tester,
  ) async {
    final entry = _entry(changes: 'نص تجريبي للتغيير');
    await _pump(tester, _row(entry, const ResourceDownloaded(2)));
    expect(find.textContaining('نص تجريبي للتغيير'), findsNothing);
  });

  testWidgets('a download under way draws no line', (tester) async {
    final entry = _entry();
    await _pump(tester, _row(entry, const ResourceDownloading(sixtyPercent)));
    expect(find.textContaining(entry.source), findsNothing);
  });

  test('a size rounds up to the tenth, in Arabic-Indic digits', () {
    expect(megabytes(_l10n, 1), _l10n.resourceSizeMegabytes('٠٫١'));
    expect(megabytes(_l10n, 100000), _l10n.resourceSizeMegabytes('٠٫١'));
    expect(megabytes(_l10n, 100001), _l10n.resourceSizeMegabytes('٠٫٢'));
    expect(megabytes(_l10n, 12300000), _l10n.resourceSizeMegabytes('١٢٫٣'));
    expect(megabytes(_l10n, 12340000), _l10n.resourceSizeMegabytes('١٢٫٤'));
  });
}
