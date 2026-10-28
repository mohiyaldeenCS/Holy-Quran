import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';

import '../../../../testing/fakes/fake_reading_position_repository.dart';
import 'mushaf_harness.dart';

/// One way the reader stops being shown, and the way it is shown again
/// (`null` when it is gone for good).
typedef _Leaving = ({
  String name,
  Future<void> Function(WidgetTester) leave,
  Future<void> Function(WidgetTester)? back,
});

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_position');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  QuranAddress at(int surah, int ayah) => QuranAddress('hafs', surah, ayah);

  late ValueNotifier<bool> shown;
  late ShellChrome chrome;

  Future<MushafViewModel> pumpReader(
    WidgetTester tester,
    FakeReadingPositionRepository positions, {
    QuranAddress? address,
  }) async {
    setReaderView(tester);
    shown = ValueNotifier(true);
    chrome = ShellChrome();
    addTearDown(shown.dispose);
    addTearDown(chrome.dispose);
    final viewModel = rig.viewModel(address: address, positions: positions);
    addTearDown(viewModel.dispose);
    await tester.pumpWidget(readerApp(viewModel, shown: shown, chrome: chrome));
    await tester.pumpAndSettle();
    return viewModel;
  }

  ScrollController controllerOf(WidgetTester tester) => tester
      .widget<CustomScrollView>(find.byType(CustomScrollView))
      .controller!;

  Future<void> dragUp(WidgetTester tester, [double by = 400]) async {
    await tester.drag(find.byType(CustomScrollView), Offset(0, -by));
    await tester.pumpAndSettle();
  }

  NavigatorState navigatorOf(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator));

  final leavings = <_Leaving>[
    (
      name: 'another route covers it',
      leave: (tester) async {
        unawaited(
          navigatorOf(tester).push(
            MaterialPageRoute<void>(builder: (_) => const SizedBox.expand()),
          ),
        );
        await tester.pumpAndSettle();
      },
      back: (tester) async {
        navigatorOf(tester).pop();
        await tester.pumpAndSettle();
      },
    ),
    (
      name: 'its tab is no longer the one shown',
      leave: (tester) async {
        shown.value = false;
        await tester.pumpAndSettle();
      },
      back: (tester) async {
        shown.value = true;
        await tester.pumpAndSettle();
      },
    ),
    (
      name: 'the app is hidden',
      leave: (tester) async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pumpAndSettle();
      },
      back: (tester) async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
      },
    ),
    (
      name: 'the app is paused',
      leave: (tester) async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
          ..handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pumpAndSettle();
      },
      back: (tester) async {
        tester.binding
          ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
          ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
          ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();
      },
    ),
    (
      name: 'the reader is closed',
      leave: (tester) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
      back: null,
    ),
  ];

  group('restoring', () {
    testWidgets('opens at the last reading position', (tester) async {
      final positions = FakeReadingPositionRepository(last: at(2, 30));
      final viewModel = await pumpReader(tester, positions);

      expect(viewModel.anchor, at(2, 30));
      expect(controllerOf(tester).offset, greaterThan(0));
      expect(viewModel.position!.address.surah, 2);
      expect(positions.saved, isEmpty);
    });

    testWidgets('the address of the route wins over the last position', (
      tester,
    ) async {
      final positions = FakeReadingPositionRepository(last: at(2, 30));
      final viewModel = await pumpReader(tester, positions, address: at(2, 5));

      expect(viewModel.anchor, at(2, 5));
    });

    testWidgets('a last position outside the edition opens the first ayah', (
      tester,
    ) async {
      final positions = FakeReadingPositionRepository(last: at(2, 400));
      final viewModel = await pumpReader(tester, positions);

      expect(viewModel.anchor, at(1, 1));
    });

    testWidgets('a word in the last position opens its ayah', (tester) async {
      final positions = FakeReadingPositionRepository(
        last: QuranAddress('hafs', 2, 30, 2),
      );
      final viewModel = await pumpReader(tester, positions);

      expect(viewModel.anchor, at(2, 30));
    });
  });

  group('saving', () {
    testWidgets('saves the first visible ayah when a user scroll ends', (
      tester,
    ) async {
      final positions = FakeReadingPositionRepository();
      final viewModel = await pumpReader(tester, positions, address: at(2, 1));
      expect(positions.saved, isEmpty);

      await dragUp(tester);

      expect(positions.saved, isNotEmpty);
      expect(positions.saved.last, viewModel.position!.address);
      expect(positions.saved.last.surah, 2);
      expect(positions.saved.last.ayah, greaterThan(1));
      expect(positions.last, positions.saved.last);
    });

    testWidgets('saves nothing while the scroll goes on', (tester) async {
      final positions = FakeReadingPositionRepository();
      await pumpReader(tester, positions, address: at(2, 1));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView)),
      );
      await gesture.moveBy(const Offset(0, -300));
      await tester.pump();
      expect(positions.saved, isEmpty);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(positions.saved, isNotEmpty);
    });

    testWidgets('only ayah addresses are saved', (tester) async {
      final positions = FakeReadingPositionRepository();
      await pumpReader(tester, positions, address: at(2, 1));

      await dragUp(tester);

      expect(positions.saved.every((address) => !address.isWord), isTrue);
    });

    for (final leaving in leavings) {
      testWidgets('saves the position when ${leaving.name}', (tester) async {
        final positions = FakeReadingPositionRepository();
        final viewModel = await pumpReader(
          tester,
          positions,
          address: at(2, 1),
        );
        await dragUp(tester);
        final position = viewModel.position!.address;
        final before = positions.saved.length;

        await leaving.leave(tester);

        expect(positions.saved.length, before + 1);
        expect(positions.saved.last, position);
      });

      testWidgets('an unmoved reader never saves when ${leaving.name}', (
        tester,
      ) async {
        final positions = FakeReadingPositionRepository(last: at(2, 30));
        await pumpReader(tester, positions);

        await leaving.leave(tester);
        await leaving.back?.call(tester);

        expect(positions.saved, isEmpty);
        expect(positions.last, at(2, 30));
      });
    }

    testWidgets('a reader only opened never overwrites the position', (
      tester,
    ) async {
      final positions = FakeReadingPositionRepository(last: at(2, 30));
      await pumpReader(tester, positions, address: at(2, 30));
      expect(controllerOf(tester).offset, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(positions.saved, isEmpty);
    });
  });

  group('coming back', () {
    for (final leaving in leavings.where((l) => l.back != null)) {
      testWidgets('keeps its place after ${leaving.name}', (tester) async {
        final positions = FakeReadingPositionRepository();
        final viewModel = await pumpReader(
          tester,
          positions,
          address: at(2, 1),
        );
        final controller = controllerOf(tester);
        controller.jumpTo(controller.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final surahs = viewModel.surahs;
        final anchor = viewModel.anchor;
        final offset = controller.offset;
        expect(surahs.length, greaterThan(1));

        await leaving.leave(tester);
        await leaving.back!(tester);

        expect(viewModel.surahs, same(surahs));
        expect(viewModel.anchor, same(anchor));
        expect(controllerOf(tester).offset, offset);
      });
    }

    testWidgets('reopens at the position a reader over it saved', (
      tester,
    ) async {
      final positions = FakeReadingPositionRepository();
      final base = await pumpReader(tester, positions, address: at(2, 1));
      await dragUp(tester);
      final first = positions.saved.last;

      final upper = rig.viewModel(address: first, positions: positions);
      addTearDown(upper.dispose);
      unawaited(
        navigatorOf(tester).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                SizedBox.expand(child: MushafScreen(viewModel: upper)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      final second = positions.saved.last;
      expect(second.ayah, greaterThan(first.ayah));
      final savedBefore = positions.saved.length;

      navigatorOf(tester).pop();
      await tester.pumpAndSettle();

      expect(base.anchor, second);
      expect(positions.saved.skip(savedBefore), everyElement(second));
      await dragUp(tester, 100);
      expect(positions.saved.last.ayah, greaterThanOrEqualTo(second.ayah));
    });
  });

  group('the tab bar', () {
    testWidgets('is hidden in distraction-free mode and given back', (
      tester,
    ) async {
      final positions = FakeReadingPositionRepository();
      final viewModel = await pumpReader(tester, positions);
      expect(chrome.tabBarVisible, isTrue);

      viewModel.setDistractionFree(true);
      await tester.pump();
      expect(chrome.tabBarVisible, isFalse);

      viewModel.setDistractionFree(false);
      await tester.pump();
      expect(chrome.tabBarVisible, isTrue);
    });

    testWidgets('is given back when the reader is closed', (tester) async {
      final positions = FakeReadingPositionRepository();
      final viewModel = await pumpReader(tester, positions);
      viewModel.setDistractionFree(true);
      await tester.pump();
      expect(chrome.tabBarVisible, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(chrome.tabBarVisible, isTrue);
    });

    testWidgets('is given back when the tab is left', (tester) async {
      final positions = FakeReadingPositionRepository();
      final viewModel = await pumpReader(tester, positions);
      viewModel.setDistractionFree(true);
      await tester.pump();

      shown.value = false;
      await tester.pumpAndSettle();

      expect(chrome.tabBarVisible, isTrue);
    });
  });
}
