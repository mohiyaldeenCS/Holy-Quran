import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/category.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/widgets/annotation_card.dart';
import 'package:holyquran/ui/core/widgets/ayah_row.dart';
import 'package:holyquran/ui/core/widgets/category_tag.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';

import '../../../../testing/golden.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));
// Synthetic, never Quran text.
const _ayah = PackText.fromPack('نص تجريبي');
const _surah = PackText.fromPack('اسم تجريبي');

Future<void> _pump(
  WidgetTester tester,
  AnnotationCard card, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 1200)
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
          child: SizedBox(width: 340, child: card),
        ),
      ),
    ),
  );
}

AnnotationCard _card({
  PackText? surahName = _surah,
  PackText? ayahText = _ayah,
  String? note,
  List<Widget> tags = const [],
  VoidCallback? onContext,
  VoidCallback? onOpen,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) => AnnotationCard(
  ayahNumber: 5,
  surahName: surahName,
  ayahText: ayahText,
  note: note,
  tags: tags,
  deleteLabel: _l10n.bookmarkDelete,
  onDelete: onDelete ?? () {},
  onContext: onContext,
  onOpen: onOpen,
  onEdit: onEdit,
);

Finder _button(String label) => find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.label == label,
);

void main() {
  testWidgets('shows the reference over the ayah in its card', (tester) async {
    await _pump(tester, _card());
    expect(
      find.text(_l10n.surahAyahReference('اسم تجريبي', '٥')),
      findsOneWidget,
    );
    expect(find.byType(AyahRow), findsOneWidget);
    expect(tester.widget<AyahRow>(find.byType(AyahRow)).number, 5);
    expect(_button(_l10n.bookmarkDelete), findsOneWidget);
  });

  testWidgets('leaves out what has no data', (tester) async {
    await _pump(tester, _card(surahName: null, ayahText: null));
    expect(find.byType(SurahName), findsNothing);
    expect(find.byType(AyahRow), findsNothing);
    expect(find.byType(Wrap), findsNothing);
    expect(_button(_l10n.searchResultContext), findsNothing);
    expect(_button(_l10n.searchResultOpen), findsNothing);
    expect(_button(_l10n.noteLabel), findsNothing);
    expect(_button(_l10n.bookmarkDelete), findsOneWidget);
  });

  testWidgets('shows a note whole, and its tags', (tester) async {
    await _pump(
      tester,
      _card(
        note: 'نص تجريبي ثان',
        tags: [
          CategoryTag(
            category: BuiltinCategory.study,
            selected: false,
            onPressed: () {},
          ),
          FreeTag(name: 'وسم تجريبي', selected: false, onPressed: () {}),
        ],
      ),
    );
    expect(find.text('نص تجريبي ثان'), findsOneWidget);
    expect(find.text(_l10n.tagStudy), findsOneWidget);
    expect(find.text('وسم تجريبي'), findsOneWidget);
  });

  testWidgets('calls the buttons it shows', (tester) async {
    final calls = <String>[];
    await _pump(
      tester,
      _card(
        onContext: () => calls.add('context'),
        onOpen: () => calls.add('open'),
        onEdit: () => calls.add('edit'),
        onDelete: () => calls.add('delete'),
      ),
    );
    for (final label in [
      _l10n.searchResultContext,
      _l10n.searchResultOpen,
      _l10n.noteLabel,
      _l10n.bookmarkDelete,
    ]) {
      await tester.tap(_button(label));
    }
    expect(calls, ['context', 'open', 'edit', 'delete']);
  });

  testWidgets('every button is 48 and named', (tester) async {
    await _pump(tester, _card(onContext: () {}, onOpen: () {}, onEdit: () {}));
    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    expect(buttons, hasLength(4));
    for (final button in buttons) {
      final size = tester.getSize(find.byWidget(button));
      expect(size.width, greaterThanOrEqualTo(48), reason: button.label);
      expect(size.height, greaterThanOrEqualTo(48), reason: button.label);
      expect(button.label, isNotEmpty);
    }
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out in ${theme.name} at 200% text', (tester) async {
      await _pump(
        tester,
        _card(
          note: 'نص تجريبي طويل يمتد على عدة أسطر ليظهر التفاف الكلام وليس آية',
          tags: [
            CategoryTag(
              category: BuiltinCategory.important,
              selected: true,
              onPressed: () {},
            ),
            FreeTag(name: 'وسم تجريبي', selected: false, onPressed: () {}),
          ],
          onContext: () {},
          onOpen: () {},
          onEdit: () {},
        ),
        theme: theme,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
