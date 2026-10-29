import 'package:flutter/material.dart' hide Stepper;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/gallery/sections/controls_gallery.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/note_editor.dart';
import 'package:holyquran/ui/core/widgets/stepper.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Future<void> _pump(
  WidgetTester tester, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: const SingleChildScrollView(child: ControlsGallery()),
        ),
      ),
    ),
  );
}

void main() {
  for (final theme in ReadingTheme.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('lays out without overflow in ${theme.name} at '
          '${(scale * 100).round()}% on 360 wide', (tester) async {
        await _pump(tester, theme: theme, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('titles its three sections', (tester) async {
    await _pump(tester);
    expect(find.text(_l10n.gallerySectionTag), findsOneWidget);
    expect(find.text(_l10n.noteLabel), findsOneWidget);
    expect(find.text(_l10n.gallerySectionStepper), findsOneWidget);
  });

  testWidgets('shows the note editor with its category, tags and actions', (
    tester,
  ) async {
    await _pump(tester);
    final editor = find.byType(NoteEditor);
    expect(editor, findsOneWidget);
    for (final label in [
      _l10n.noteHint,
      _l10n.tagNewHint,
      _l10n.noteSave,
      _l10n.noteDelete,
      _l10n.noteAdd,
      _l10n.tagMemorise,
      _l10n.tagImportant,
      _l10n.sampleWord,
    ]) {
      expect(
        find.descendant(of: editor, matching: find.textContaining(label)),
        findsWidgets,
        reason: label,
      );
    }
  });

  testWidgets('the note editor chooses and clears its category', (
    tester,
  ) async {
    await _pump(tester);
    Tag category(String label) => tester.widget<Tag>(
      find.descendant(
        of: find.byType(NoteEditor),
        matching: find.widgetWithText(Tag, label),
      ),
    );
    expect(category(_l10n.tagMemorise).selected, isTrue);
    await tester.tap(find.widgetWithText(Tag, _l10n.tagStudy).last);
    await tester.pump();
    expect(category(_l10n.tagStudy).selected, isTrue);
    expect(category(_l10n.tagMemorise).selected, isFalse);
    await tester.tap(find.widgetWithText(Tag, _l10n.tagStudy).last);
    await tester.pump();
    expect(category(_l10n.tagStudy).selected, isFalse);
  });

  testWidgets('shows each shape selected and not, in theme colours', (
    tester,
  ) async {
    await _pump(tester);
    // The editor has tags of its own.
    final inEditor = tester
        .widgetList<Tag>(
          find.descendant(
            of: find.byType(NoteEditor),
            matching: find.byType(Tag),
          ),
        )
        .toSet();
    final tags = tester
        .widgetList<Tag>(find.byType(Tag))
        .where((tag) => !inEditor.contains(tag))
        .toList();
    expect(tags, hasLength(8));
    for (final shape in TagShape.values) {
      final ofShape = tags.where((tag) => tag.shape == shape);
      expect(ofShape.map((tag) => tag.selected).toSet(), {true, false});
    }
    const colors = AppColors.paper;
    expect(tags.map((tag) => tag.color).toSet(), {
      colors.primary,
      colors.accent,
      colors.info,
      colors.error,
    });
  });

  testWidgets('a tag toggles when pressed', (tester) async {
    await _pump(tester);
    bool selected() => tester.widget<Tag>(find.byType(Tag).first).selected;
    expect(selected(), isTrue);
    await tester.tap(find.byType(Tag).first);
    await tester.pump();
    expect(selected(), isFalse);
  });

  testWidgets('shows the three steppers of the preview, and they step', (
    tester,
  ) async {
    await _pump(tester);
    final steppers = tester.widgetList<Stepper>(find.byType(Stepper)).toList();
    expect(steppers.map((stepper) => stepper.value), [7, 3, 3]);
    expect(steppers.last.unit, _l10n.galleryStepperSeconds);
    expect(steppers.last.min, 0);

    await tester.tap(
      find.bySemanticsLabel(_l10n.stepperIncrease(_l10n.galleryStepperRepeat)),
    );
    await tester.pump();
    expect(tester.widget<Stepper>(find.byType(Stepper).first).value, 8);
  });
}
