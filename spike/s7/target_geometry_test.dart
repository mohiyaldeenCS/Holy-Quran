import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/quran_address.dart';

import '../s1/render/page_blocks_v2.dart';
import '../s1/render/render_checks.dart';
import '../s1/render/spike_surah_text.dart';
import '../s1/render/surah_paragraph.dart';
import '../s1/render/synthetic_surah_pack.dart';
import 'target_geometry.dart';

// Every text is Arabic-script nonsense with marks from the spike writer's
// pack (D-083), read through the app's verification and text repository.

const _pageMark = Size(30, 20);
const _eps = 0.5;

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

QuranAddress _word(QuranAddress ayah, int number) =>
    QuranAddress(ayah.riwaya, ayah.surah, ayah.ayah, number);

/// The marks whose first code unit starts a shown line of [paragraph].
Set<(QuranAddress, int)> _marksStartingLines(SurahParagraph paragraph) {
  final content = paragraph.content;
  return {
    for (final start in paragraph.lineStartPositions)
      if (content.indexOf(_ayah(content, start.ayah)) case final i?)
        for (final mark in content.marks[i])
          if (mark.start == start.offset) (content.ayahAt(i), mark.number),
  };
}

QuranAddress _ayah(SurahBlockContent content, int ayah) =>
    QuranAddress(content.firstAyah.riwaya, content.firstAyah.surah, ayah);

int _bandOf(List<Rect> bands, Rect rect) => bands.indexWhere(
  (b) => b.top <= rect.center.dy && rect.center.dy < b.bottom,
);

void main() {
  late Directory root;
  late SpikeSurahText long;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('s7_geometry');
    final read = await readSyntheticSurahs(root, withMarks: true);
    long = _first(read.long, 100);
    read.pack.close();
  });
  tearDownAll(() => root.delete(recursive: true));

  var withoutBoxSeen = 0;
  for (final scale in [1.0, 2.0]) {
    for (final width in [320.0, 360.0, 412.0]) {
      final where = '${width.toInt()} wide at ${scale}x';

      test('the geometry is the paragraph\'s boxes, markers and bands, and '
          'every shown mark has a box between its neighbours unless it '
          'starts a line ($where)', () {
        final paragraph = surahParagraph(
          long,
          width: width,
          textScaler: TextScaler.linear(scale),
          pageMarkSize: _pageMark,
        );
        addTearDown(paragraph.dispose);
        final g = TargetGeometry.of(paragraph);
        final content = paragraph.content;
        final bands = paragraph.lineBands;
        expect(g.lineBands, bands);

        var shownMarks = 0;
        final words = <QuranAddress, List<Rect>>{};
        for (var i = 0; i < content.length; i++) {
          final ayah = content.ayahAt(i);
          for (final word in content.words[i]) {
            final address = _word(ayah, word.number);
            final boxes = paragraph.boxesOf(address);
            if (boxes.isNotEmpty) words[address] = boxes;
          }
          expect(g.markers[ayah], paragraph.markerRect(i));
          final tokens = content.marks[i];
          for (final mark in tokens) {
            shownMarks++;
            final box = g.marks[(ayah, mark.number)];
            if (box == null) continue;
            final band = _bandOf(bands, box);
            expect(box.width, greaterThan(0));
            expect(band, isNot(-1));
            expect(box.top, greaterThanOrEqualTo(bands[band].top - _eps));
            expect(box.bottom, lessThanOrEqualTo(bands[band].bottom + _eps));
            expect(box.left, greaterThanOrEqualTo(0));
            expect(box.right, lessThanOrEqualTo(width));
            Rect? onLine(List<Rect> rects) {
              final same = rects.where((r) => _bandOf(bands, r) == band);
              return same.isEmpty ? null : same.single;
            }

            // Right to left: what comes before lies to the right.
            if (mark.afterWord > 0) {
              final before = onLine(
                paragraph.boxesOf(_word(ayah, mark.afterWord)),
              );
              if (before != null) {
                expect(before.left, greaterThanOrEqualTo(box.right - _eps));
              }
            }
            final next = content.words[i].where(
              (w) => w.number == mark.afterWord + 1,
            );
            final followedByMark = tokens.any(
              (m) => m.afterWord == mark.afterWord && m.start > mark.start,
            );
            if (followedByMark) continue;
            final after = next.isEmpty
                ? onLine([paragraph.markerRect(i)])
                : onLine(paragraph.boxesOf(_word(ayah, next.single.number)));
            if (after != null) {
              expect(after.right, lessThanOrEqualTo(box.left + _eps));
            }
          }
        }
        expect(g.words.keys.toSet(), words.keys.toSet());
        for (final MapEntry(:key, :value) in words.entries) {
          expect(g.words[key], value, reason: '$key');
        }
        // Found on this pack: a mark that opens its ayah follows the
        // marker's placeholder with no space and has no box either, even
        // mid-line; on the line before one that starts with a mark, the
        // engine puts the boxes of the last tokens past the left edge (part
        // 1's words beside a line-start mark); and a mark that starts a line
        // now and then has a box.
        final startingLines = _marksStartingLines(paragraph);
        final opening = {
          for (var i = 0; i < content.length; i++)
            for (final mark in content.marks[i])
              if (mark.start == 0) (content.ayahAt(i), mark.number),
        };
        final beforeMarkLines = {
          for (final mark in startingLines)
            paragraph.markBoxOf(mark.$1, mark.$2)!.line - 1,
        };
        final besideLineStart = {
          for (final mark in g.marksWithoutBox)
            if (beforeMarkLines.contains(
              paragraph.markBoxOf(mark.$1, mark.$2)!.line,
            ))
              mark,
        }.difference(startingLines).difference(opening);
        expect(
          g.marksWithoutBox.toSet().difference(startingLines),
          opening
              .union(besideLineStart)
              .intersection(g.marksWithoutBox.toSet()),
          reason: 'after a space, mid-line, every mark has a box',
        );
        expect(g.marks.length + g.marksWithoutBox.length, shownMarks);
        withoutBoxSeen += g.marksWithoutBox.length;
        final startingWithBox = startingLines.difference(
          g.marksWithoutBox.toSet(),
        );
        // ignore: avoid_print
        print(
          'geometry $where: $shownMarks marks, '
          '${g.marksWithoutBox.length} without a box, '
          '${startingLines.length} starting a line '
          '(${startingWithBox.length} of them with a box: $startingWithBox), '
          '${opening.length} opening an ayah '
          '(${opening.difference(g.marksWithoutBox.toSet()).length} with a '
          'box), ${besideLineStart.length} on the line before a line-start '
          'mark, ${paragraph.lineCount} lines',
        );
      });
    }
  }

  test('some shown mark starts a line and has no box', () {
    expect(withoutBoxSeen, greaterThan(0));
  });

  test('a lone combining mark has no box of its own (Flutter 3.44.7 draws '
      'it on the space before it); with the space it has one', () {
    var checked = 0;
    for (var i = 0; i < long.ayat.length && checked < 20; i++) {
      for (final mark in long.marks[i]) {
        if (mark.afterWord == 0) continue;
        final painter = TextPainter(
          text: TextSpan(text: long.ayat[i].verbatim, style: quranPageStyle),
          textDirection: TextDirection.rtl,
        )..layout(maxWidth: 100000);
        double widthOf(int start, int end) => painter
            .getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: end),
            )
            .fold(0, (sum, box) => sum + box.toRect().width);
        expect(widthOf(mark.start, mark.end), 0, reason: 'ayah ${i + 1}');
        expect(widthOf(mark.start - 1, mark.end), greaterThan(0));
        painter.dispose();
        if (++checked == 20) break;
      }
    }
    expect(checked, 20);
  });

  test('within keeps the full geometry on the lines it meets', () {
    final paragraph = surahParagraph(
      long,
      width: 360,
      textScaler: const TextScaler.linear(2),
      pageMarkSize: _pageMark,
    );
    addTearDown(paragraph.dispose);
    final full = TargetGeometry.of(paragraph);
    final content = paragraph.content;
    final lineOfMark = {
      for (var i = 0; i < content.length; i++)
        for (final mark in content.marks[i])
          (content.ayahAt(i), mark.number): paragraph
              .markBoxOf(content.ayahAt(i), mark.number)!
              .line,
    };
    var checked = 0;
    for (final band in [
      ...full.lineBands.take(6),
      ...full.lineBands.skip(40),
    ]) {
      for (final y in [band.top, band.center.dy, band.bottom - 0.01]) {
        final within = Rect.fromLTRB(0, y - 48, 360, y + 48);
        final kept = {
          for (final (k, b) in full.lineBands.indexed)
            if (b.overlaps(within)) k,
        };
        bool keeps(Rect r) => kept.contains(_bandOf(full.lineBands, r));
        final cut = TargetGeometry.of(paragraph, within: within);
        expect(cut.lineBands, [for (final k in kept) full.lineBands[k]]);
        final words = {
          for (final MapEntry(:key, :value) in full.words.entries)
            if (value.where(keeps).toList() case final rects
                when rects.isNotEmpty)
              key: rects,
        };
        expect(cut.words.keys.toSet(), words.keys.toSet());
        for (final MapEntry(:key, :value) in words.entries) {
          expect(cut.words[key], value);
        }
        expect(cut.marks, {
          for (final MapEntry(:key, :value) in full.marks.entries)
            if (kept.contains(lineOfMark[key])) key: value,
        });
        expect(cut.marksWithoutBox, [
          for (final mark in full.marksWithoutBox)
            if (kept.contains(lineOfMark[mark])) mark,
        ]);
        expect(cut.markers, {
          for (final MapEntry(:key, :value) in full.markers.entries)
            if (keeps(value)) key: value,
        });
        checked++;
      }
    }
    expect(checked, greaterThan(20));
    expect(
      TargetGeometry.of(
        paragraph,
        within: const Rect.fromLTRB(0, -200, 360, -100),
      ).lineBands,
      isEmpty,
    );
  });

  test('hidden lead-in and cut lines give no targets', () {
    final planner = SurahFlowPlanner(
      surah: long,
      width: 360,
      textScaler: const TextScaler.linear(1),
      pageMarkSize: _pageMark,
    );
    final block = planner.all.firstWhere(
      (b) => b.leadIn > 0 && b.maxLines != null,
    );
    final paragraph = planner.paragraphFor(block);
    addTearDown(paragraph.dispose);
    final content = paragraph.content;
    final g = TargetGeometry.of(paragraph);
    expect(g.lineBands, paragraph.lineBands);
    expect(paragraph.visibleLineCount, lessThan(paragraph.lineCount));
    final top = g.lineBands.first.top;
    final bottom = g.lineBands.last.bottom;
    bool shown(Rect r) => top <= r.center.dy && r.center.dy < bottom;
    for (final rects in g.words.values) {
      expect(rects.every(shown), isTrue);
    }
    expect(g.marks.values.every(shown), isTrue);
    expect(g.markers.values.every(shown), isTrue);
    final last = content.ayahAt(content.length - 1);
    expect(g.markers.containsKey(last), isFalse, reason: 'past maxLines');
    var hiddenWords = 0;
    for (var i = 0; i < content.length; i++) {
      final ayah = content.ayahAt(i);
      for (final word in content.words[i]) {
        if (paragraph.boxesOf(_word(ayah, word.number)).isEmpty) {
          hiddenWords++;
          expect(g.words.containsKey(_word(ayah, word.number)), isFalse);
        }
      }
      for (final mark in content.marks[i]) {
        if (paragraph.markBoxOf(ayah, mark.number) == null) {
          expect(g.marks.containsKey((ayah, mark.number)), isFalse);
          expect(g.marksWithoutBox, isNot(contains((ayah, mark.number))));
        }
      }
    }
    expect(hiddenWords, greaterThan(0));
  });
}
