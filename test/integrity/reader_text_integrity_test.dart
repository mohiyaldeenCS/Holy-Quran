import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/pack_failure.dart';
import 'package:holyquran/domain/models/pack_integrity.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';

import '../../testing/packs/synthetic_pack.dart';
import '../ui/features/mushaf/mushaf_harness.dart';
import '../ui/features/mushaf/provided_pack_harness.dart';
import 'pack_integrity_suite.dart';

// The surah-mode reader shows the stored bytes of every ayah (PRD sections
// 9.4, 9.5; RD-01) and, while the base pack fails its check, none of its
// text. The texts are the reader's synthetic surahs, read through the
// production repositories; the bytes they are compared with come from the
// independent reader. A screen reader reads the label of each ayah, so the
// labels are the bytes the reader says.

void main() {
  late Directory root;
  late MushafRig rig;
  late MushafRig distinct;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('reader_text_integrity');
    rig = await MushafRig.load(Directory('${root.path}/rig'));
    distinct = await MushafRig.load(
      Directory('${root.path}/distinct'),
      distinctAyat: true,
    );
  });
  tearDownAll(() async {
    rig.close();
    distinct.close();
    await root.delete(recursive: true);
  });

  tearDown(() => rig.integrity.report(MushafRig.packId, const IntegrityOk()));

  /// The stored text of every ayah of the pack, in order.
  Iterable<(String, List<int>)> storedAyat() sync* {
    for (final surah in rig.pack.raw.surahs()) {
      for (final (number, bytes) in rig.pack.raw.ayat(surah.number)) {
        yield ('${surah.number}:$number', bytes);
      }
    }
  }

  testWidgets('each ayah is read as the bytes stored at its own address', (
    tester,
  ) async {
    setReaderView(tester);
    final semantics = tester.ensureSemantics();
    final viewModel = distinct.viewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(readerApp(viewModel));
    await tester.pumpAndSettle();

    final surahs = distinct.pack.raw.surahs();
    final snapshots = await labelSnapshotsScrollingToEnd(
      tester,
      viewModel,
      lastSurah: surahs.last.number,
    );

    // Each ayah has a text of its own, so a label names one address. A screen
    // reader meets one surah's ayat in order, so the labels of each surah on
    // screen are a run of its stored ayat; the runs together cover them all.
    final byBytes = <String, (int, int)>{};
    var total = 0;
    for (final surah in surahs) {
      for (final (number, bytes) in distinct.pack.raw.ayat(surah.number)) {
        expect(byBytes[base64.encode(bytes)], isNull, reason: 'distinct');
        byBytes[base64.encode(bytes)] = (surah.number, number);
        total++;
      }
    }
    final problems = <String>[];
    final covered = <(int, int)>{};
    for (final snapshot in snapshots) {
      final last = <int, int>{};
      for (final label in snapshot) {
        final address = byBytes[base64.encode(utf8.encode(label))];
        if (address == null) continue;
        final (surah, ayah) = address;
        final before = last[surah];
        if (before != null && ayah != before + 1) {
          problems.add('$surah:$before is followed by $surah:$ayah');
        }
        last[surah] = ayah;
        covered.add(address);
      }
    }
    for (final address in byBytes.values) {
      if (!covered.contains(address)) {
        problems.add(
          '${address.$1}:${address.$2}: no semantics label holds its bytes',
        );
      }
    }
    expect(covered, hasLength(total));
    expect(total, distinct.pack.manifest.counts.ayat);
    expectNoProblems(problems);
    semantics.dispose();
  });

  testWidgets('every basmala shown is the stored one', (tester) async {
    setReaderView(tester);
    final viewModel = rig.viewModel();
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(readerApp(viewModel));
    await tester.pumpAndSettle();

    final stored = {
      for (final surah in rig.pack.raw.surahs())
        if (surah.basmala != null) base64.encode(surah.basmala!),
    };
    for (final surah in viewModel.surahs) {
      final basmala = surah.text.basmala;
      if (basmala != null) {
        expect(stored, contains(base64.encode(utf8.encode(basmala.verbatim))));
      }
    }
    for (final widget in tester.widgetList<QuranText>(find.byType(QuranText))) {
      expect(
        stored,
        contains(base64.encode(utf8.encode(widget.text.verbatim))),
        reason: 'a QuranText on screen that is not a stored basmala',
      );
    }
  });

  group('while the base pack fails its check', () {
    bool showsNoPackText(WidgetTester tester) {
      final labels = semanticLabels(tester);
      final stored = {
        for (final (_, bytes) in storedAyat()) base64.encode(bytes),
      };
      final ayahLabelled = labels.any(
        (label) => stored.contains(base64.encode(utf8.encode(label))),
      );
      return find.byType(QuranText).evaluate().isEmpty &&
          find.byType(CustomScrollView).evaluate().isEmpty &&
          !ayahLabelled;
    }

    testWidgets('a failure in the middle of reading removes the text', (
      tester,
    ) async {
      setReaderView(tester);
      final semantics = tester.ensureSemantics();
      final viewModel = rig.viewModel(address: QuranAddress('hafs', 2, 5));
      addTearDown(viewModel.dispose);
      await tester.pumpWidget(readerApp(viewModel));
      await tester.pumpAndSettle();
      expect(viewModel.status, ReaderStatus.ready);
      expect(showsNoPackText(tester), isFalse);

      rig.integrity.report(
        MushafRig.packId,
        const IntegrityFailed(ManifestUnreadable(MushafRig.packId, 'x')),
      );
      await tester.pumpAndSettle();

      expect(viewModel.status, ReaderStatus.unavailable);
      expect(viewModel.surahs, isEmpty);
      expect(find.byType(IntegrityAlert), findsOneWidget);
      expect(showsNoPackText(tester), isTrue);
      semantics.dispose();
    });

    for (final fault in [
      SyntheticFault.flippedByte,
      SyntheticFault.wrongCounts,
      SyntheticFault.wrongSurahHash,
    ]) {
      testWidgets('a pack with ${fault.name} shows no text', (tester) async {
        setReaderView(tester);
        final semantics = tester.ensureSemantics();
        final pack = (await tester.runAsync(
          () => ProvidedPack.load(
            Directory('${root.path}/${fault.name}'),
            fault: fault,
          ),
        ))!;
        addTearDown(pack.close);
        final viewModel = pack.viewModel();
        addTearDown(viewModel.dispose);

        await tester.pumpWidget(readerApp(viewModel));
        await tester.pumpAndSettle();

        expect(viewModel.status, ReaderStatus.unavailable);
        expect(viewModel.surahs, isEmpty);
        expect(find.byType(IntegrityAlert), findsOneWidget);
        expect(showsNoPackText(tester), isTrue);
        semantics.dispose();
      });
    }
  });
}
