import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/main.dart' show AppStart;
import 'package:provider/single_child_widget.dart';

import '../application_support.dart';

/// The app's Arabic words, from the same file the app reads, so that a flow
/// names a control as the user hears it.
final AppLocalizations flowL10n = lookupAppLocalizations(const Locale('ar'));

/// The size of the phones the flows run on, in logical pixels.
const flowPhone = Size(390, 844);

/// Puts the app in front of the user: [AppStart] over [providers], on a phone
/// sized view. Semantics must be on, so that controls are found by name.
Future<void> pumpFlowApp(
  WidgetTester tester,
  List<SingleChildWidget> providers,
) async {
  tester.view
    ..physicalSize = flowPhone
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(AppStart(dependencies: Future.value(providers)));
  await tester.pumpAndSettle();
}

/// Removes the app from the tree, so that what it holds can be closed.
Future<void> leaveFlowApp(WidgetTester tester) async {
  resumeApp(tester);
  await tester.pumpWidget(const SizedBox());
  // A read the screens started may still be on its way to the database.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
}

/// Runs [action] with real time, as a call to the database or a file needs;
/// the widget test's own clock never finishes one.
Future<T> real<T>(WidgetTester tester, Future<T> Function() action) async =>
    (await tester.runAsync(action)) as T;

/// The user comes back to the app. A paused app draws no frames.
void resumeApp(WidgetTester tester) {
  final binding = tester.binding;
  final state = binding.lifecycleState;
  if (state == null || state == AppLifecycleState.resumed) return;
  if (state == AppLifecycleState.paused) {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  }
  if (state != AppLifecycleState.inactive) {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  }
  binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

/// The user leaves the app, which saves what it keeps in memory.
void pauseApp(WidgetTester tester) => tester.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.paused);

/// Lets real input and output finish until [done] holds, then lets the
/// animations end.
Future<void> settle(WidgetTester tester, [bool Function()? done]) async {
  if (done != null) await pumpUntil(tester, done);
  // What the session started runs in real time, outside the test's clock.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 10)),
  );
  await tester.pumpAndSettle();
}

/// Taps the control with the spoken name [label] and waits for [done].
Future<void> tapNamed(
  WidgetTester tester,
  Pattern label, {
  bool Function()? done,
}) async {
  final target = find.bySemanticsLabel(label);
  expect(target, findsWidgets, reason: 'no control named "$label"');
  await tester.tap(target.first);
  await settle(tester, done);
}

/// The text that `Clipboard.setData` was given, in order, while the test runs.
List<String> recordClipboard(WidgetTester tester) {
  final copied = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments as Map<Object?, Object?>;
        copied.add(arguments['text']! as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return copied;
}

/// The spoken names on screen, to assert what the user hears.
Set<String> spokenNames(WidgetTester tester) {
  final names = <String>{};
  void visit(SemanticsNode node) {
    if (node.label.isNotEmpty) names.add(node.label);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
  );
  return names;
}

/// Taps the control named [label] inside [within], where the same name is
/// also on a control beneath, and waits for [done].
Future<void> tapNamedIn(
  WidgetTester tester,
  Finder within,
  Pattern label, {
  bool Function()? done,
}) async {
  final target = find.descendant(
    of: within,
    matching: find.bySemanticsLabel(label),
  );
  expect(target, findsWidgets, reason: 'no control named "$label" there');
  await tester.tap(target.first);
  await settle(tester, done);
}
