import 'package:flutter/material.dart' hide Icon;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon.dart';
import 'package:holyquran/ui/core/widgets/note_editor.dart';
import 'package:holyquran/ui/core/widgets/tag.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

const _categories = [
  Category(id: 'c-memorise', builtin: BuiltinCategory.memorise),
  Category(id: 'c-review', builtin: BuiltinCategory.review),
  Category(id: 'c-study', builtin: BuiltinCategory.study),
  Category(id: 'c-important', builtin: BuiltinCategory.important),
];

final _tags = [
  UserTag(id: 't-a', name: 'وسم أول', createdAt: DateTime.utc(2026)),
  UserTag(id: 't-b', name: 'وسم ثان', createdAt: DateTime.utc(2026)),
];

/// Calls the editor makes, in order, as `name` or `name:argument`.
final class _Calls {
  final log = <String>[];
  final body = TextEditingController();
  final newTag = TextEditingController();
}

NoteEditor _editor(
  _Calls calls, {
  String? category,
  Set<String> tagIds = const {},
  bool canSave = true,
  bool saved = false,
  List<String> existing = const [],
  int? selectedExisting,
}) => NoteEditor(
  controller: calls.body,
  categories: _categories,
  selectedCategoryId: category,
  onCategoryChanged: (id) => calls.log.add('category:$id'),
  tags: _tags,
  selectedTagIds: tagIds,
  onTagToggled: (id) => calls.log.add('tag:$id'),
  newTagController: calls.newTag,
  onTagAdded: () => calls.log.add('addTag'),
  onSave: canSave ? () => calls.log.add('save') : null,
  onDelete: saved ? () => calls.log.add('delete') : null,
  existing: existing,
  selectedExisting: selectedExisting,
  onExistingSelected: (index) => calls.log.add('existing:$index'),
  onNew: () => calls.log.add('new'),
);

Future<void> _pump(
  WidgetTester tester,
  NoteEditor editor, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 3000)
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
          child: SingleChildScrollView(child: editor),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the text, the four categories, the tags and the save', (
    tester,
  ) async {
    await _pump(tester, _editor(_Calls()));
    expect(find.text(_l10n.noteHint), findsOneWidget);
    expect(find.text(_l10n.categoryLabel), findsOneWidget);
    expect(find.text(_l10n.tagsLabel), findsOneWidget);
    for (final label in [
      _l10n.tagMemorise,
      _l10n.tagReview,
      _l10n.tagStudy,
      _l10n.tagImportant,
      'وسم أول',
      'وسم ثان',
    ]) {
      expect(find.widgetWithText(Tag, label), findsOneWidget, reason: label);
    }
    expect(find.text(_l10n.tagNewHint), findsOneWidget);
    expect(find.widgetWithText(Button, _l10n.noteSave), findsOneWidget);
    expect(find.widgetWithText(Button, _l10n.noteDelete), findsNothing);
    expect(find.widgetWithText(Button, _l10n.noteAdd), findsNothing);
  });

  testWidgets('cannot be saved while onSave is null', (tester) async {
    await _pump(tester, _editor(_Calls(), canSave: false));
    expect(
      tester
          .widget<Button>(find.widgetWithText(Button, _l10n.noteSave))
          .onPressed,
      isNull,
    );
  });

  testWidgets('pressing a category chooses it, and the chosen one clears', (
    tester,
  ) async {
    final calls = _Calls();
    await _pump(tester, _editor(calls));
    await tester.tap(find.widgetWithText(Tag, _l10n.tagStudy));
    expect(calls.log, ['category:c-study']);

    await _pump(tester, _editor(calls, category: 'c-study'));
    expect(
      tester.widget<Tag>(find.widgetWithText(Tag, _l10n.tagStudy)).selected,
      isTrue,
    );
    await tester.tap(find.widgetWithText(Tag, _l10n.tagStudy));
    expect(calls.log.last, 'category:null');
  });

  testWidgets('pressing a tag toggles it, and the chosen tags show chosen', (
    tester,
  ) async {
    final calls = _Calls();
    await _pump(tester, _editor(calls, tagIds: {'t-b'}));
    expect(
      tester.widget<Tag>(find.widgetWithText(Tag, 'وسم أول')).selected,
      isFalse,
    );
    expect(
      tester.widget<Tag>(find.widgetWithText(Tag, 'وسم ثان')).selected,
      isTrue,
    );
    await tester.tap(find.widgetWithText(Tag, 'وسم أول'));
    expect(calls.log, ['tag:t-a']);
  });

  testWidgets('the new-tag field and the save send what they are for', (
    tester,
  ) async {
    final calls = _Calls();
    await _pump(tester, _editor(calls));
    final fields = find.byType(TextField);
    await tester.enterText(fields.first, 'نص تجريبي');
    await tester.enterText(fields.last, 'وسم جديد');
    expect(calls.body.text, 'نص تجريبي');
    expect(calls.newTag.text, 'وسم جديد');

    await tester.tap(find.widgetWithText(Button, _l10n.tagAdd));
    await tester.tap(find.widgetWithText(Button, _l10n.noteSave));
    expect(calls.log, ['addTag', 'save']);
  });

  testWidgets('lists the notes the ayah has and chooses one', (tester) async {
    final calls = _Calls();
    await _pump(
      tester,
      _editor(
        calls,
        saved: true,
        existing: ['نص أول', 'نص ثان'],
        selectedExisting: 1,
      ),
    );
    expect(find.text('نص أول'), findsOneWidget);
    expect(find.text('نص ثان'), findsOneWidget);
    expect(find.widgetWithText(Button, _l10n.noteDelete), findsOneWidget);

    await tester.tap(find.text('نص أول'));
    await tester.tap(find.widgetWithText(Button, _l10n.noteAdd));
    await tester.tap(find.widgetWithText(Button, _l10n.noteDelete));
    expect(calls.log, ['existing:0', 'new', 'delete']);
  });

  testWidgets('the chosen note carries a check as well as its fill', (
    tester,
  ) async {
    Finder check(String text) => find.descendant(
      of: find.ancestor(of: find.text(text), matching: find.byType(Row)).first,
      matching: find.byType(Icon),
    );
    await _pump(
      tester,
      _editor(_Calls(), existing: ['نص أول', 'نص ثان'], selectedExisting: 0),
    );
    expect(check('نص أول'), findsOneWidget);
    expect(check('نص ثان'), findsNothing);
  });

  testWidgets('every control is at least 48 high, and the fields are named', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      _editor(_Calls(), saved: true, existing: ['نص أول'], selectedExisting: 0),
    );
    for (final button in tester.widgetList<Button>(find.byType(Button))) {
      expect(
        tester.getSize(find.byWidget(button)).height,
        greaterThanOrEqualTo(48),
        reason: button.label,
      );
    }
    for (final tag in tester.widgetList<Tag>(find.byType(Tag))) {
      expect(
        tester.getSize(find.byWidget(tag)).height,
        greaterThanOrEqualTo(48),
        reason: tag.label,
      );
    }
    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expect(
        tester.getSize(find.byWidget(field)).height,
        greaterThanOrEqualTo(48),
      );
    }
    expect(find.bySemanticsLabel(_l10n.categoryLabel), findsOneWidget);
    expect(find.bySemanticsLabel(_l10n.tagsLabel), findsOneWidget);
    handle.dispose();
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out in ${theme.name} at 200% text on 360 wide', (
      tester,
    ) async {
      await _pump(
        tester,
        _editor(
          _Calls(),
          category: 'c-review',
          tagIds: {'t-a'},
          saved: true,
          existing: ['نص تجريبي طويل يمتد على عدة أسطر ليظهر التفاف الكلام'],
          selectedExisting: 0,
        ),
        theme: theme,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
