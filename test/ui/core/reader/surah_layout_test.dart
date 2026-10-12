import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/ui/core/reader/block_layout.dart';
import 'package:holyquran/ui/core/reader/reader_paragraph.dart';
import 'package:holyquran/ui/core/reader/reader_style.dart';
import 'package:holyquran/ui/core/reader/reader_text_scale.dart';
import 'package:holyquran/ui/core/reader/surah_layout.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import 'reader_fixture.dart';

const _ink = AppColors.paper;

/// The widths and scales the spike measured at, and a narrow phone at the
/// largest reader step on top of the largest system scale.
const _cases = [
  (width: 360.0, system: 1.0, step: 1.0),
  (width: 412.0, system: 1.0, step: 1.0),
  (width: 360.0, system: 2.0, step: 1.0),
  (width: 320.0, system: 2.0, step: 2.0),
];

ReaderStyle _style(double system, double step) =>
    ReaderStyle(ReaderTextScaler(TextScaler.linear(system), step));

List<BlockLayout> _laidOut(SurahLayout plan) => [
  for (var b = 0; b < plan.blocks.length; b++)
    BlockLayout(plan, b, ink: _ink.quranInk),
];

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('surah_layout');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  for (final size in _cases) {
    final name = '${size.width}/${size.system}x/${size.step}';

    test('every ayah drawn rejoins to its stored bytes, $name', () {
      for (final MapEntry(key: number, value: surah)
          in fixture.surahs.entries) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        final drawn = <int, StringBuffer>{};
        for (final segment in plan.segments) {
          for (final run in segmentRuns(
            plan.plannedAyat(segment),
            plan.style,
            colourOfLine: (_) => _ink.quranInk,
          )) {
            if (run is TextRun) {
              (drawn[run.ayah] ??= StringBuffer()).write(run.text);
            }
          }
        }
        final stored = fixture.pack.raw.ayat(number);
        expect(drawn.keys, [for (final (ayah, _) in stored) ayah]);
        for (final (ayah, bytes) in stored) {
          expect(
            utf8.encode(drawn[ayah].toString()),
            bytes,
            reason: 'surah $number ayah $ayah',
          );
        }
      }
    });

    test('the paragraphs break where the plan does, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        for (final block in _laidOut(plan)) {
          expect(
            block.laidLineStarts,
            block.plannedLineStarts,
            reason: 'surah ${surah.surah} block ${block.index}',
          );
          expect(block.matchesPlan, isTrue);
          block.dispose();
        }
      }
    });

    test('no line starts with a mark cut from its word, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        for (final block in _laidOut(plan)) {
          for (final start in block.laidLineStarts) {
            final ayah = surah.ayat[start.ayah];
            final allowed = {-1, 0, for (final word in ayah.words) word.start};
            expect(
              allowed,
              contains(start.offset),
              reason: 'surah ${surah.surah} ayah ${start.ayah + 1}',
            );
            expect(
              ayah.marks.map((mark) => mark.start),
              isNot(contains(start.offset)),
            );
          }
          block.dispose();
        }
      }
    });

    test('blocks break their lines as one block does, $name', () {
      final surah = fixture.surahs[longSurah]!;
      final style = _style(size.system, size.step);
      final blocks = SurahLayout.plan(surah, style, size.width, blockLines: 6);
      final whole = SurahLayout.plan(
        surah,
        style,
        size.width,
        blockLines: 1 << 30,
      );
      expect(whole.blocks, hasLength(1));
      expect(blocks.blocks.length, greaterThan(2));
      final split = [
        for (final block in _laidOut(blocks)) ...block.laidLineStarts,
      ];
      final one = _laidOut(whole).single;
      expect(split, one.laidLineStarts);
      expect(split, [
        for (var line = 0; line < whole.lines.length; line++)
          whole.lineStart(line),
      ]);
      one.dispose();
    });

    test('lines fit their width and every line is one height, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        expect(plan.lines.every((line) => line.natural <= size.width), isTrue);
        for (final block in _laidOut(plan)) {
          for (final ayah in block.ayat) {
            for (final box in [
              ...block.ayahBoxes(ayah),
              block.markerRect(ayah)!,
              ?block.pageMarkRect(ayah),
            ]) {
              expect(box.left, greaterThanOrEqualTo(-0.01));
              expect(box.right, lessThanOrEqualTo(size.width + 0.01));
              expect(box.top, greaterThanOrEqualTo(-0.01));
              expect(box.bottom, lessThanOrEqualTo(block.height + 0.01));
            }
          }
          block.dispose();
        }
      }
    });

    test('the surah ends on a centred line, $name', () {
      for (final surah in fixture.surahs.values) {
        final plan = SurahLayout.plan(
          surah,
          _style(size.system, size.step),
          size.width,
        );
        final blocks = _laidOut(plan);
        final last = blocks.last;
        final lastAyah = surah.ayat.length;
        final band = last.lineBand(last.lineCount - 1);
        final ink = [
          for (final ayah in last.ayat)
            ...last.ayahBoxes(ayah).where((box) => box.center.dy > band.top),
        ];
        final marker = last.markerRect(lastAyah)!;
        final left = marker.left;
        final right = ink
            .map((box) => box.right)
            .reduce((a, b) => a > b ? a : b);
        expect((left + right) / 2, closeTo(size.width / 2, 1));
        for (final block in blocks) {
          block.dispose();
        }
      }
    });
  }

  test('a word wider than the line is drawn smaller and stays whole', () {
    final surah = fixture.surahs[overwideSurah]!;
    final plan = SurahLayout.plan(surah, _style(2, 2), 320);
    final block = BlockLayout(plan, 0, ink: _ink.quranInk);
    final box = block.wordBox(1, 2)!;
    expect(box.width, lessThanOrEqualTo(320));
    expect(box.left, greaterThanOrEqualTo(0));
    final line = (box.center.dy / plan.lineHeight).floor();
    expect(box.top, closeTo(line * plan.lineHeight, 0.01));
    expect(block.matchesPlan, isTrue);
    block.dispose();
  });

  test('the text size steps run from 80% to 200% over the system scale', () {
    expect(readerTextSteps, [0.8, 0.9, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0]);
    expect(readerTextSteps[defaultReaderTextStep], 1.0);
    expect(nearestReaderTextStep(1.22), readerTextSteps.indexOf(1.15));
    expect(nearestReaderTextStep(3), readerTextSteps.length - 1);
    const scaler = ReaderTextScaler(TextScaler.linear(2), 1.5);
    expect(scaler.scale(25), 75);
    final surah = fixture.surahs[longSurah]!;
    double heightAt(double step) =>
        SurahLayout.plan(surah, _style(1, step), 360).lineHeight;
    // SkParagraph rounds line heights to whole pixels.
    expect(heightAt(2) / heightAt(1), closeTo(2, 0.03));
    expect(
      SurahLayout.plan(surah, _style(1, 2), 360).lines.length,
      greaterThan(SurahLayout.plan(surah, _style(1, 1), 360).lines.length),
    );
  });

  test('the basmala stands alone except in al-Fatiha and al-Tawba', () {
    expect(fixture.surahs[1]!.basmala, isNotNull);
    expect(fixture.surahs[1]!.showsBasmala, isFalse);
    expect(fixture.surahs[9]!.basmala, isNull);
    expect(fixture.surahs[9]!.showsBasmala, isFalse);
    expect(fixture.surahs[longSurah]!.showsBasmala, isTrue);
    final shown = SurahLayout.plan(
      fixture.surahs[longSurah]!,
      _style(1, 1),
      360,
    );
    final none = SurahLayout.plan(fixture.surahs[9]!, _style(1, 1), 360);
    expect(shown.basmalaExtent, greaterThan(0));
    expect(none.basmalaExtent, 0);
  });

  test('positions round-trip from an address to an offset and back', () {
    final surah = fixture.surahs[longSurah]!;
    final plan = SurahLayout.plan(surah, _style(1, 1), 360);
    var previous = -1.0;
    for (var ayah = 1; ayah <= surah.ayat.length; ayah++) {
      final offset = plan.offsetOf(surah.addressOf(ayah));
      expect(offset, greaterThanOrEqualTo(previous));
      previous = offset;
      final at = plan.ayahAt(offset + plan.lineHeight / 2);
      final line = plan.lines[plan.lineOfAyah(ayah)];
      expect(at, surah.addressOf(line.start.ayah + 1));
      expect(at.ayah, lessThanOrEqualTo(ayah));
    }
    expect(plan.ayahAt(0), surah.addressOf(1));
    expect(
      plan.ayahAt(plan.height * 2),
      surah.addressOf(plan.lines.last.start.ayah + 1),
    );
  });
}
