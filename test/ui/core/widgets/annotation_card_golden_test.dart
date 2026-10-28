@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/annotation_card.dart';
import 'package:holyquran/ui/core/widgets/category_tag.dart';
import 'package:holyquran/ui/core/widgets/undo_bar.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
// Synthetic, never Quran text.
const _ayah = PackText.fromPack('نص تجريبي');
const _surah = PackText.fromPack('اسم تجريبي');

void main() {
  testWidgets('AnnotationCard as a bookmark, as a note, and the undo bar', (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'annotation_card',
      (context) => SizedBox(
        width: 340,
        child: goldenColumn([
          AnnotationCard(
            ayahNumber: 5,
            surahName: _surah,
            ayahText: _ayah,
            deleteLabel: _l10n.bookmarkDelete,
            onDelete: () {},
            onContext: () {},
            onOpen: () {},
            tags: [
              CategoryTag(
                category: BuiltinCategory.memorise,
                selected: false,
                onPressed: () {},
              ),
              FreeTag(name: 'وسم تجريبي', selected: false, onPressed: () {}),
            ],
          ),
          AnnotationCard(
            ayahNumber: 12,
            surahName: _surah,
            ayahText: _ayah,
            note: 'ملاحظة تجريبية',
            deleteLabel: _l10n.noteDelete,
            onDelete: () {},
            onContext: () {},
            onOpen: () {},
            onEdit: () {},
            tags: [
              CategoryTag(
                category: BuiltinCategory.important,
                selected: true,
                onPressed: () {},
              ),
            ],
          ),
          UndoBar(message: _l10n.itemDeleted, onUndo: () {}),
        ]),
      ),
      surfaceSize: const Size(400, 820),
    );
  });
}
