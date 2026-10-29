import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:holyquran/ui/core/shell_chrome.dart';
import 'package:holyquran/ui/core/widgets/reader_player_bar.dart';
import 'package:holyquran/ui/features/mushaf/view_models/mushaf_view_model.dart';
import 'package:holyquran/ui/features/mushaf/views/mushaf_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_player_repository.dart';
import 'mushaf_harness.dart';
import 'recitation_fixture.dart';

void main() {
  late Directory root;
  late MushafRig rig;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mushaf_chrome');
    rig = await MushafRig.load(root);
  });
  tearDownAll(() async {
    rig.close();
    await root.delete(recursive: true);
  });

  late FakePlayerRepository player;
  late ShellChrome chrome;

  MushafViewModel reader() {
    final viewModel = rig.viewModel(address: ayahAt(2, 1), player: player);
    addTearDown(viewModel.dispose);
    return viewModel;
  }

  Widget screen(MushafViewModel viewModel) => SizedBox.fromSize(
    size: const Size(readerWidth, readerHeight),
    child: MushafScreen(key: ObjectKey(viewModel), viewModel: viewModel),
  );

  setUp(() {
    player = FakePlayerRepository();
    chrome = ShellChrome();
    addTearDown(chrome.dispose);
  });

  testWidgets('a reader removed while it hides them gives the mini player and '
      'the tab bar back', (tester) async {
    setReaderView(tester);
    final viewModel = reader();
    await tester.pumpWidget(readerApp(viewModel, chrome: chrome));
    await tester.pumpAndSettle();
    player.reach(recitationPlan(), ayahSegment(2, 2));
    viewModel.setDistractionFree(true);
    await tester.pumpAndSettle();
    expect(chrome.miniPlayerVisible, isFalse);
    expect(chrome.tabBarVisible, isFalse);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();

    expect(chrome.miniPlayerVisible, isTrue);
    expect(chrome.tabBarVisible, isTrue);
  });

  testWidgets('readers stacked over each other keep them hidden until the '
      'last lets go', (tester) async {
    setReaderView(tester);
    final below = reader();
    final above = reader();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => screen(below)),
        GoRoute(path: '/over', builder: (context, state) => screen(above)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: chrome,
        child: readerRouterApp(router),
      ),
    );
    await tester.pumpAndSettle();
    player.reach(recitationPlan(), ayahSegment(2, 2));
    await tester.pumpAndSettle();
    expect(chrome.miniPlayerVisible, isFalse);

    unawaited(router.push<Object?>('/over'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPlayerBar), findsOneWidget);
    expect(chrome.miniPlayerVisible, isFalse);

    router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPlayerBar), findsOneWidget);
    expect(chrome.miniPlayerVisible, isFalse);

    await player.stop();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderPlayerBar), findsNothing);
    expect(chrome.miniPlayerVisible, isTrue);
  });

  testWidgets('the tab bar of a reader below stays hidden when the one above '
      'is popped', (tester) async {
    setReaderView(tester);
    final below = reader();
    final above = reader();
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => screen(below)),
        GoRoute(path: '/over', builder: (context, state) => screen(above)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: chrome,
        child: readerRouterApp(router),
      ),
    );
    await tester.pumpAndSettle();
    below.setDistractionFree(true);
    await tester.pumpAndSettle();
    expect(chrome.tabBarVisible, isFalse);

    unawaited(router.push<Object?>('/over'));
    await tester.pumpAndSettle();
    above.setDistractionFree(true);
    await tester.pumpAndSettle();

    router.pop();
    await tester.pumpAndSettle();

    expect(chrome.tabBarVisible, isFalse);
  });
}
