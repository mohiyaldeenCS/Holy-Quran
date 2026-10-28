import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/repositories/reading_position_repository.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:holyquran/utils/result.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_pack_integrity_repository.dart';
import '../../../../testing/golden.dart';
import '../../../../testing/packs/synthetic_pack.dart';
import '../../../integrity/pack_integrity_suite.dart';
import '../../core/reader/reader_fixture.dart';

const readerWidth = 360.0;
const readerHeight = 640.0;

/// The reader's synthetic pack, open, with the index and integrity the view
/// model reads. Every text is synthetic (`reader_fixture.dart`); one surah
/// of each place of revelation carries it.
final class MushafRig {
  MushafRig._(this.pack, this.text, this.index, this.integrity);

  static const packId = 'synthetic-text';

  /// The surah that gives no place of revelation.
  static const surahWithoutPlace = 2;

  /// [distinctAyat] gives every ayah a text of its own, so that a label
  /// names one address.
  static Future<MushafRig> load(
    Directory root, {
    bool distinctAyat = false,
  }) async {
    var count = 0;
    String distinct(String text) {
      var n = count++;
      final suffix = <String>[];
      do {
        suffix.add(readerWords[n % readerWords.length]);
        n ~/= readerWords.length;
      } while (n > 0);
      return '$text ${suffix.join(' ')}';
    }

    final built = await buildSyntheticPack(
      root,
      surahs: [
        for (final (index, surah) in readerSurahs.indexed)
          SyntheticSurah(
            name: surah.name,
            basmala: surah.basmala,
            ayat: distinctAyat
                ? [
                    for (final ayah in surah.ayat)
                      SyntheticAyah(distinct(ayah.text)),
                  ]
                : surah.ayat,
            revelationPlace: switch (index + 1) {
              surahWithoutPlace => null,
              final number when number.isOdd => 'makki',
              _ => 'madani',
            },
          ),
      ],
      divisions: readerDivisions,
      sajdas: const [(longSurah, sajdaAyah)],
    );
    final pack = await PackUnderTest.load(built.directory.path);
    final text = pack.openRepository();
    final integrity = FakePackIntegrityRepository({
      packId: const IntegrityOk(),
    });
    final index = switch (PackQuranIndexRepository.build(
      riwaya: text.riwaya,
      surahs: _ok(await text.surahs()),
      map: _ok(await text.editionMap()),
      serving: () => integrity.stateOf(packId) is IntegrityOk,
    )) {
      Ok(:final value) => value,
      Failure(:final error) => throw StateError('$error'),
    };
    return MushafRig._(pack, text, index, integrity);
  }

  final PackUnderTest pack;
  final PackQuranTextRepository text;
  final PackQuranIndexRepository index;
  final FakePackIntegrityRepository integrity;

  MushafViewModel viewModel({
    QuranAddress? address,
    ReadingPositionRepository? positions,
  }) => MushafViewModel(
    text: text,
    index: index,
    positions: positions,
    integrity: integrity,
    address: address,
  );

  void close() {
    integrity.dispose();
    pack.close();
  }
}

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Failure(:final error) => throw StateError('$error'),
};

/// The reader on a phone-sized view, in [theme] at system text scale
/// [textScale]. [shown] stands for the tab being the one shown.
Widget readerApp(
  MushafViewModel viewModel, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
  Size size = const Size(readerWidth, readerHeight),
  ShellChrome? chrome,
  ValueListenable<bool>? shown,
}) => goldenApp(
  theme,
  Builder(
    builder: (context) {
      Widget screen = SizedBox.fromSize(
        size: size,
        child: MushafScreen(key: ObjectKey(viewModel), viewModel: viewModel),
      );
      if (shown != null) {
        final inner = screen;
        screen = ValueListenableBuilder<bool>(
          valueListenable: shown,
          builder: (_, enabled, _) =>
              TickerMode(enabled: enabled, child: inner),
        );
      }
      if (chrome != null) {
        screen = ChangeNotifierProvider.value(value: chrome, child: screen);
      }
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: screen,
      );
    },
  ),
);

void setReaderView(WidgetTester tester, [Size? size]) {
  tester.view
    ..physicalSize = size ?? const Size(readerWidth, readerHeight)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ScrollController scrollOf(WidgetTester tester) =>
    tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;

/// Every semantics label on screen, in the order a screen reader meets them.
/// Needs `tester.ensureSemantics()`.
List<String> semanticLabelList(WidgetTester tester) {
  final labels = <String>[];
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    // The order a screen reader moves in, not the tree's.
    node
        .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
        .forEach(visit);
  }

  visit(
    tester
        .renderObject(find.byType(MushafScreen))
        .owner!
        .semanticsOwner!
        .rootSemanticsNode!,
  );
  return labels;
}

/// Every semantics label on screen. Needs `tester.ensureSemantics()`.
Set<String> semanticLabels(WidgetTester tester) =>
    semanticLabelList(tester).toSet();

/// Scrolls the reader from where it is to the end of the last surah of the
/// pack, half a screen at a time, and returns the labels it showed at each
/// step, in reading order. Needs `tester.ensureSemantics()`.
Future<List<List<String>>> labelSnapshotsScrollingToEnd(
  WidgetTester tester,
  MushafViewModel viewModel, {
  required int lastSurah,
}) async {
  final snapshots = <List<String>>[];
  final controller = scrollOf(tester);
  for (var step = 0; step < 1000; step++) {
    snapshots.add(semanticLabelList(tester));
    final position = controller.position;
    final atEnd = position.pixels >= position.maxScrollExtent;
    if (atEnd && viewModel.surahs.last.info.number == lastSurah) {
      return snapshots;
    }
    controller.jumpTo(
      (position.pixels + position.viewportDimension / 2).clamp(
        0,
        position.maxScrollExtent,
      ),
    );
    await tester.pumpAndSettle();
  }
  fail('The reader did not reach the end of surah $lastSurah.');
}

/// Every label [labelSnapshotsScrollingToEnd] showed.
Future<Set<String>> labelsFromScrollingToEnd(
  WidgetTester tester,
  MushafViewModel viewModel, {
  required int lastSurah,
}) async => {
  for (final snapshot in await labelSnapshotsScrollingToEnd(
    tester,
    viewModel,
    lastSurah: lastSurah,
  ))
    ...snapshot,
};
