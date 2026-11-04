import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';

import '../../../../testing/golden.dart';
import 'reader_fixture.dart';

// D-171 (2): the keyboard ring round an ayah follows its lines, one ring per
// line box, so it never covers an ayah that shares a line.

const _width = 360.0;
const _height = 640.0;

/// The stroked rects the focus ring paints on the focused ayah, in global
/// coordinates of [block]: [gap] those in `ground`, otherwise those in
/// `focus`. Focusing scrolls, so a block's own coordinates are the ones that
/// hold still.
List<Rect> _painted(WidgetTester tester, Finder block, {required bool gap}) {
  final colour = gap ? AppColors.paper.ground : AppColors.paper.focus;
  final painted = tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .where((paint) => paint.foregroundPainter != null);
  expect(painted, hasLength(1), reason: 'one ring is drawn, on one ayah');
  final box = tester.renderObject<RenderBox>(find.byWidget(painted.single));
  final canvas = TestRecordingCanvas();
  final context = TestRecordingPaintingContext(canvas);
  box.paint(context, Offset.zero);
  final origin = box.localToGlobal(
    Offset.zero,
    ancestor: tester.renderObject(block),
  );
  return [
    for (final call in canvas.invocations)
      if (call.invocation.memberName == #drawRRect)
        if ((call.invocation.positionalArguments[1] as Paint).color
                .toARGB32() ==
            colour.toARGB32())
          (call.invocation.positionalArguments[0] as RRect).outerRect.shift(
            origin,
          ),
  ];
}

void main() {
  late Directory root;
  late ReaderFixture fixture;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('ayah_focus_ring');
    fixture = await ReaderFixture.load(root);
  });
  tearDownAll(() async {
    fixture.close();
    await root.delete(recursive: true);
  });

  testWidgets('each ayah is ringed line by line and no ring meets another', (
    tester,
  ) async {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(
      () => FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic,
    );
    tester.view
      ..physicalSize = const Size(_width, _height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      goldenApp(
        ReadingTheme.paper,
        SizedBox(
          width: _width,
          height: _height,
          child: CustomScrollView(
            slivers: [
              InteractiveSurahSliver(
                text: fixture.surahs[longSurah]!,
                onTap: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    var sharedLine = 0;
    var manyLines = 0;
    for (final block in tester.widgetList<ReaderBlock>(
      find.byType(ReaderBlock),
    )) {
      final layout = block.layout;
      final rings = <int, List<Rect>>{};
      for (final (k, ayah) in layout.ayat.indexed) {
        final detector = find
            .descendant(
              of: find.byWidget(block),
              matching: find.byType(FocusableActionDetector),
            )
            .at(k);
        final inner = find.descendant(
          of: detector,
          matching: find.byType(SizedBox),
        );
        Focus.of(tester.element(inner.first)).requestFocus();
        await tester.pumpAndSettle();
        final ring = _painted(tester, find.byWidget(block), gap: false);
        final gap = _painted(tester, find.byWidget(block), gap: true);
        final lines = layout.ayahLines(ayah);
        expect(ring, hasLength(lines.length), reason: 'ayah $ayah');
        expect(gap, hasLength(lines.length), reason: 'ayah $ayah');
        for (final (line, rect) in ring.indexed) {
          expect(
            lines[line].inflate(0.5).contains(rect.topLeft) &&
                lines[line].inflate(0.5).contains(rect.bottomRight),
            isTrue,
            reason: 'the ring of ayah $ayah, line $line, stays on its line',
          );
        }
        rings[ayah] = ring;
        if (lines.length > 1) manyLines++;
      }
      final numbers = rings.keys.toList();
      for (final (i, a) in numbers.indexed) {
        for (final b in numbers.skip(i + 1)) {
          for (final x in rings[a]!) {
            for (final y in rings[b]!) {
              expect(x.overlaps(y), isFalse, reason: 'ayat $a and $b');
            }
          }
          final share = layout
              .ayahLines(a)
              .any((x) => layout.ayahLines(b).any((y) => x.top == y.top));
          if (share) sharedLine++;
        }
        for (final (j, x) in rings[a]!.indexed) {
          for (final y in rings[a]!.skip(j + 1)) {
            expect(x.overlaps(y), isFalse, reason: 'lines of ayah $a');
          }
        }
      }
    }
    expect(sharedLine, greaterThan(0), reason: 'two ayat that share a line');
    expect(manyLines, greaterThan(0), reason: 'an ayah of more than one line');
  });
}
