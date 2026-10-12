import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/search_form.dart';

void main() {
  const form = PackText.fromPack(' synthetic e\u{301} form ');

  test('holds a word, its kind and the form as given', () {
    final word = QuranAddress('hafs', 1, 2, 3);
    final searchForm = SearchForm(word: word, kind: 'synthetic-a', form: form);
    expect(searchForm.word, word);
    expect(searchForm.kind, 'synthetic-a');
    expect(searchForm.form, same(form));
  });

  test('refuses an ayah address', () {
    expect(
      () => SearchForm(word: QuranAddress('hafs', 1, 2), kind: 'a', form: form),
      throwsArgumentError,
    );
  });

  test('accepts kinds of lower-case words joined by - or _', () {
    for (final kind in ['a', 'a1', 'synthetic-plain', 'synthetic_spelled']) {
      expect(SearchForm.kindPattern.hasMatch(kind), isTrue, reason: kind);
    }
    for (final kind in ['', 'A', 'a b', '-a', 'a-', 'a--b', 'a.b', 'é']) {
      expect(SearchForm.kindPattern.hasMatch(kind), isFalse, reason: kind);
      expect(
        () => SearchForm(
          word: QuranAddress('hafs', 1, 1, 1),
          kind: kind,
          form: form,
        ),
        throwsArgumentError,
        reason: kind,
      );
    }
  });
}
