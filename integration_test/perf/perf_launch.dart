import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/ui_level.dart';
import 'package:holyquran/main.dart' as app;
import 'package:holyquran/ui/core/reader/reader_block.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../testing/application_support.dart';
import '../../testing/packs/synthetic_pack.dart' show amiriQuranFontPath;
import 'perf_app.dart';
import 'perf_pack.dart';
import 'perf_run.dart';

bool get _onDevice => Platform.isAndroid || Platform.isIOS;

/// The application support folder: the device's own, or on a computer a new
/// temporary folder that path_provider is made to answer with.
Future<Directory> perfSupportFolder() async => _onDevice
    ? getApplicationSupportDirectory()
    : useTemporaryApplicationSupport();

/// The pinned font's bytes from the app's bundle on a device, which has no
/// repository path to read them from; null on a computer, which has.
Future<Uint8List?> perfFontBytes() async => _onDevice
    ? (await rootBundle.load(amiriQuranFontPath)).buffer.asUint8List()
    : null;

/// Opens the harness over the application support folder, building the pack
/// there when an earlier run of the install has not. The next start opens the
/// reader at [seed] at the level [level] when the pack was built now or when
/// [reseed] is set. A start that must find the pack as an earlier launch left
/// it, as a cold start does, leaves [reseed] off and reads [PerfApp.packReused]
/// to know whether it did.
Future<PerfApp> preparePerfApp(
  WidgetTester tester, {
  required PerfPackSize size,
  required QuranAddress seed,
  bool reseed = false,
  UiLevel level = UiLevel.medium,
}) async {
  final support = await perfSupportFolder();
  final perf = (await tester.runAsync(
    () async => PerfApp.open(
      size: size,
      support: support,
      fontBytes: await perfFontBytes(),
    ),
  ))!;
  if (reseed || !perf.packReused) {
    await tester.runAsync(() async {
      final started = await perf.start();
      await started.settings.setOpenAtLastPosition(true);
      await started.settings.setLevel(level);
      await started.positions!.save(seed);
      await started.close();
    });
  }
  return perf;
}

/// The marks of a start, in milliseconds from its beginning.
typedef LaunchMarks = ({
  double splashMs,
  double dependenciesMs,
  double readerShownMs,
});

/// One launch of the app in [tester], and what it holds open.
final class Launched {
  Launched._(this.start, this.marks);

  final PerfStart start;
  final LaunchMarks marks;
  bool _closed = false;

  /// The router of the running app.
  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(MushafScreen)));

  MushafViewModel reader(WidgetTester tester) => Provider.of<MushafViewModel>(
    tester.element(find.byType(MushafScreen)),
    listen: false,
  );

  /// Takes the app out of the tree and closes what it opened, after the
  /// reads and writes the reader started on its way out have ended.
  Future<void> close(WidgetTester tester) async {
    _closed = true;
    await tester.pumpWidget(const SizedBox());
    // The reader's reads of the user database are a chain of a few queries,
    // and a future of the tree's zone advances only with a pump.
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    await tester.runAsync(start.close);
  }
}

/// Whether the reader shows text: ready, with a block drawn, and, when it was
/// to open away from the top of the surah, scrolled there.
bool readerShown(WidgetTester tester, {required bool scrolled}) {
  if (find.byType(MushafScreen).evaluate().isEmpty) return false;
  final reader = Provider.of<MushafViewModel>(
    tester.element(find.byType(MushafScreen)),
    listen: false,
  );
  if (reader.status != ReaderStatus.ready ||
      find.byType(ReaderBlock).evaluate().isEmpty) {
    return false;
  }
  if (!scrolled) return true;
  final scrollable = find.descendant(
    of: find.byType(MushafScreen),
    matching: find.byType(Scrollable),
  );
  return scrollable.evaluate().isNotEmpty &&
      tester.state<ScrollableState>(scrollable.first).position.pixels > 0;
}

/// Starts the app as `main` does, over [perf], and waits for the reader to
/// show text, taking the marks of the start. The splash is pumped first and
/// the dependencies are built after it, so the sum is the start's, one step
/// after the other.
Future<Launched> launch(
  WidgetTester tester,
  PerfApp perf, {
  required bool scrolled,
}) async {
  if (!isLiveBinding(tester)) {
    // A phone, as a device would give; a plain widget test has a tiny view.
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  final built = Completer<List<SingleChildWidget>>();
  final clock = Stopwatch()..start();
  markTimeline('start');
  await tester.pumpWidget(app.AppStart(dependencies: built.future));
  final splash = clock.elapsed;
  final start = (await tester.runAsync(perf.start))!;
  built.complete(start.providers);
  final dependencies = clock.elapsed;
  markTimeline('dependenciesBuilt');
  final shown = await pumpUntilFrame(
    tester,
    clock,
    () => readerShown(tester, scrolled: scrolled),
  );
  markTimeline('readerShown');
  final launched = Launched._(start, (
    splashMs: millis(splash),
    dependenciesMs: millis(dependencies),
    readerShownMs: millis(shown),
  ));
  // A failed run still releases the files, which Windows will not delete open.
  addTearDown(() async {
    if (!launched._closed) await start.close();
  });
  return launched;
}
