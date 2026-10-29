@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/user_tag.dart';
import 'package:holyquran/ui/core/widgets/note_editor.dart';

import '../../../../testing/golden.dart';

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

void main() {
  testWidgets('NoteEditor holding a saved note among two', (tester) async {
    final body = TextEditingController(text: 'نص تجريبي');
    final newTag = TextEditingController();
    addTearDown(body.dispose);
    addTearDown(newTag.dispose);
    await expectGoldensInThemes(
      tester,
      'note_editor',
      (context) => SizedBox(
        width: 340,
        child: NoteEditor(
          controller: body,
          categories: _categories,
          selectedCategoryId: 'c-review',
          onCategoryChanged: (_) {},
          tags: _tags,
          selectedTagIds: const {'t-b'},
          onTagToggled: (_) {},
          newTagController: newTag,
          onTagAdded: () {},
          onSave: () {},
          onDelete: () {},
          existing: const ['نص أول', 'نص تجريبي'],
          selectedExisting: 1,
          onExistingSelected: (_) {},
          onNew: () {},
        ),
      ),
      surfaceSize: const Size(400, 1000),
    );
  });
}
