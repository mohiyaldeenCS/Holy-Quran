import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/app_theme.dart';

import '../s1/render/render_checks.dart';
import '../s1/render/spike_surah_text.dart';
import '../s1/render/surah_list_v1.dart';
import '../s1/render/surah_text_block.dart';
import '../s1/render/synthetic_surah_pack.dart';
import 'reader_gestures.dart';
import 'text_size_ladder.dart';

// Every text is Arabic-script nonsense with marks from the spike writer's
// pack (D-083), read through the app's verification and text repository.

const _width = 360.0;
const _height = 800.0;

SpikeSurahText _first(SpikeSurahText surah, int ayat) => SpikeSurahText(
  firstAyah: surah.firstAyah,
  ayat: surah.ayat.sublist(0, ayat),
  words: surah.words.sublist(0, ayat),
  marks: surah.marks.sublist(0, ayat),
  basmala: surah.basmala,
  pageStarts: {
    for (final MapEntry(:key, :value) in surah.pageStarts.entries)
      if (key.ayah <= ayat) key: value,
  },
);

/// V1 under a pinch that steps the text size and, after the frame, jumps
/// to keep the focal ayah under the fingers, as the S7 screen will.
final class _LadderReader extends StatefulWidget {
  const _LadderReader({required this.surah, required this.controller});

  final SpikeSurahText surah;
  final ScrollController controller;

  @override
  State<_LadderReader> createState() => _LadderReaderState();
}

final class _LadderReaderState extends State<_LadderReader> {
  final _block = GlobalKey();
  double step = 1;
  FocalAyah? focal;

  RenderSurahTextBlock get block =>
      _block.currentContext!.findRenderObject()! as RenderSurahTextBlock;

  void _pinched(double scale, Offset point) {
    final local = block.globalToLocal(point);
    final kept = focalAyahAt(block.paragraph, local);
    final inViewport = local.dy - widget.controller.offset;
    setState(() {
      focal = kept;
      step = stepAfterPinch(step, scale);
    });
    if (kept == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final y = yOfFocalAyah(block.paragraph, kept);
      if (y != null) widget.controller.jumpTo(y - inViewport);
    });
  }

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(step)),
    child: ReaderPinch(
      onPinchEnd: _pinched,
      child: SurahListV1(
        surah: widget.surah,
        controller: widget.controller,
        blockKey: _block,
      ),
    ),
  );
}

void main() {
  test('stepAfterPinch takes the nearest step on a log scale, held to the '
      'ladder', () {
    expect(stepAfterPinch(1.0, 1.0), 1.0);
    expect(stepAfterPinch(1.0, 1.06), 1.0);
    expect(stepAfterPinch(1.0, 1.1), 1.15);
    expect(stepAfterPinch(1.0, 0.5), 0.8);
    expect(stepAfterPinch(2.0, 3), 2.0);
    expect(stepAfterPinch(1.07, 1), 1.0, reason: 'off the ladder: nearest');
    expect(stepAfterPinch(1.0, 0), 0.8);
    expect(textSizeSteps.first, 0.8);
    expect(textSizeSteps.last, 2.0);
    for (final current in [0.8, 1.0, 1.3, 2.0, 1.07]) {
      var last = 0.0;
      for (var scale = 0.2; scale < 4; scale *= 1.01) {
        final step = stepAfterPinch(current, scale);
        expect(step, greaterThanOrEqualTo(last), reason: '$current x $scale');
        expect(textSizeSteps, contains(step));
        last = step;
      }
    }
  });

  group('the marked surah', () {
    late Directory root;
    late SpikeSurahText surah;

    setUpAll(() async {
      root = await Directory.systemTemp.createTemp('s7_ladder');
      final read = await readSyntheticSurahs(root, withMarks: true);
      surah = _first(read.long, 120);
      read.pack.close();
    });
    tearDownAll(() => root.delete(recursive: true));

    test('the focal ayah round-trips through another size', () {
      final small = surahParagraph(
        surah,
        width: _width,
        textScaler: const TextScaler.linear(1),
      );
      final large = surahParagraph(
        surah,
        width: _width,
        textScaler: const TextScaler.linear(1.75),
      );
      addTearDown(small.dispose);
      addTearDown(large.dispose);
      final band = small.lineBands[200];
      final focal = focalAyahAt(small, band.center)!;
      expect(focal.fraction, inInclusiveRange(0, 1));
      expect(yOfFocalAyah(small, focal), closeTo(band.center.dy, 0.01));
      final y = yOfFocalAyah(large, focal)!;
      final boxes = large.boxesOf(focal.ayah);
      expect(y, inInclusiveRange(boxes.first.top, boxes.last.bottom));
      expect(focalAyahAt(small, Offset(_width / 2, small.height + 10)), isNull);
    });

    for (final (where, y) in [
      ('top', 100.0),
      ('middle', 400.0),
      ('bottom', 700.0),
    ]) {
      testWidgets('a pinch out and in at the viewport\'s $where changes the '
          'step and keeps the focal ayah under the fingers', (tester) async {
        tester.view
          ..physicalSize = const Size(_width, _height)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = ScrollController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(ReadingTheme.paper),
            locale: const Locale('ar'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            debugShowCheckedModeBanner: false,
            home: Material(
              child: _LadderReader(surah: surah, controller: controller),
            ),
          ),
        );
        controller.jumpTo(controller.position.maxScrollExtent / 2);
        await tester.pump();
        final reader = tester.state<_LadderReaderState>(
          find.byType(_LadderReader),
        );

        for (final outward in [true, false]) {
          final before = reader.step;
          final focal = Offset(_width / 2, y);
          final a = await tester.startGesture(focal.translate(0, -60));
          final b = await tester.startGesture(focal.translate(0, 60));
          for (var i = 0; i < 10; i++) {
            await a.moveBy(Offset(0, outward ? -5 : 5));
            await tester.pump(const Duration(milliseconds: 16));
            await b.moveBy(Offset(0, outward ? 5 : -5));
            await tester.pump(const Duration(milliseconds: 16));
          }
          await a.up();
          await b.up();
          await tester.pump();
          await tester.pump();
          expect(
            reader.step,
            outward ? greaterThan(before) : lessThan(before),
            reason: 'pinch ${outward ? 'out' : 'in'}',
          );
          final kept = reader.focal!;
          final paragraph = reader.block.paragraph;
          final local = reader.block.globalToLocal(focal);
          final band = paragraph.lineBands.indexWhere(
            (b) => b.top <= local.dy && local.dy < b.bottom,
          );
          expect(band, isNot(-1));
          final line = paragraph.lineBands[band];
          expect(
            paragraph
                .boxesOf(kept.ayah)
                .any(
                  (box) =>
                      line.top <= box.center.dy && box.center.dy < line.bottom,
                ),
            isTrue,
            reason: '${kept.ayah} under the fingers at ${reader.step}x',
          );
          // ignore: avoid_print
          print(
            'ladder at the $where: ${outward ? 'out' : 'in'} $before to '
            '${reader.step}, focal ${kept.ayah} at '
            '${kept.fraction.toStringAsFixed(2)}',
          );
        }
      });
    }
  });
}
