import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/reader/interactive_surah_sliver.dart';
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/focus_ring.dart';

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
      .where((paint) => paint.painter is FocusRingPainter);
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
              matching: find.byType(FocusRing),
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

  testWidgets('an ayah\'s focus claims no hover hits over its text', (
    tester,
  ) async {
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
    final rings = find.descendant(
      of: find.byType(ReaderBlock),
      matching: find.byType(FocusRing),
    );
    expect(rings, findsWidgets);
    expect(
      find.descendant(of: rings, matching: find.byType(MouseRegion)),
      findsNothing,
    );
  });

  // The reviewer's check of P1-35: text ink is every pixel in the theme's
  // `quran-ink` before the ayah is focused, outside the ayat's markers. The
  // ring is painted under the text, so focusing an ayah changes none of them.
  for (final theme in ReadingTheme.values) {
    testWidgets(
      'focusing an ayah changes no pixel of text ink in ${theme.name}',
      (tester) async {
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
        const surface = ValueKey('ink-surface');
        await tester.pumpWidget(
          goldenApp(
            theme,
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
            key: surface,
          ),
        );
        final ink = AppColors.byId[theme.name]!.quranInk.toARGB32();

        Future<Uint8List> render() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(surface),
          );
          return (await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes = await image.toByteData();
            image.dispose();
            return bytes!.buffer.asUint8List();
          }))!;
        }

        int pixel(Uint8List bytes, int at) =>
            (0xFF << 24) |
            (bytes[at] << 16) |
            (bytes[at + 1] << 8) |
            bytes[at + 2];

        // Every marker on screen, in the surface's pixels, at the current scroll.
        List<Rect> markers() {
          final origin = tester.getTopLeft(find.byKey(surface));
          return [
            for (final block in tester.widgetList<ReaderBlock>(
              find.byType(ReaderBlock),
            ))
              for (final ayah in block.layout.ayat)
                block.layout
                    .markerRect(ayah)!
                    .shift(tester.getTopLeft(find.byWidget(block)) - origin),
          ];
        }

        var focused = 0;
        var inkPixels = 0;
        var ringPixels = 0;
        for (final block in tester.widgetList<ReaderBlock>(
          find.byType(ReaderBlock),
        )) {
          for (final (k, ayah) in block.layout.ayat.indexed) {
            final ring = find
                .descendant(
                  of: find.byWidget(block),
                  matching: find.byType(FocusRing),
                )
                .at(k);
            final inner = find.descendant(
              of: ring,
              matching: find.byType(SizedBox),
            );
            Focus.of(tester.element(inner.first)).requestFocus();
            await tester.pumpAndSettle();
            final withRing = await render();
            FocusManager.instance.primaryFocus!.unfocus();
            await tester.pumpAndSettle();
            final without = await render();
            final excluded = markers();
            focused++;

            var repainted = 0;
            for (var at = 0; at < without.length; at += 4) {
              final before = pixel(without, at);
              final changed = pixel(withRing, at) != before;
              if (changed) ringPixels++;
              if (before != ink) continue;
              final point = Offset(
                (at ~/ 4) % _width + 0.5,
                (at ~/ 4) ~/ _width + 0.5,
              );
              if (excluded.any((rect) => rect.contains(point))) continue;
              inkPixels++;
              if (changed) repainted++;
            }
            expect(
              repainted,
              0,
              reason:
                  'ayah $ayah: the ring repainted $repainted pixels of text ink',
            );
          }
        }
        expect(focused, greaterThan(10), reason: 'ayat focused');
        expect(inkPixels, greaterThan(10000), reason: 'the text was drawn');
        expect(
          ringPixels,
          greaterThan(focused * 100),
          reason: 'rings were drawn',
        );
      },
    );
  }
}
