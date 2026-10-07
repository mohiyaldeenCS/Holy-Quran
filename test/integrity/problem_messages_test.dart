import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/packs/raw_pack.dart';
import '../../testing/packs/synthetic_pack.dart';
import 'pack_integrity_suite.dart';
import 'synthetic_surahs.dart';

// The integrity suite runs on the real text in CI, so no message it prints
// may hold a stored text: only addresses, offsets, lengths, digests and code
// points. These tests run every check on faulty synthetic packs and search
// the messages for each stored value, each non-ASCII word and each stored
// byte sequence, as decimal lists or hex. Every string here is synthetic.

/// The texts a pack stores, from what was written and from the file itself.
List<List<int>> _storedValues(SyntheticPack pack) {
  final values = <List<int>>[
    for (final surah in pack.surahs) ...[
      utf8.encode(surah.name),
      if (surah.basmala case final basmala?) utf8.encode(basmala),
      for (final ayah in surah.ayat) utf8.encode(ayah.text),
    ],
  ];
  if (!pack.textFile.existsSync()) return values;
  final raw = RawPack.open(pack.textFile);
  try {
    for (final surah in raw.surahs()) {
      values.add(surah.name);
      if (surah.basmala case final basmala?) values.add(basmala);
      for (final (_, bytes) in raw.ayat(surah.number)) {
        values.add(bytes);
      }
    }
  } finally {
    raw.close();
  }
  return values;
}

/// The word and mark slices of the pack that hold a non-ASCII character.
List<String> _nonAsciiSlices(SyntheticPack pack) => [
  for (final surah in pack.surahs)
    for (final ayah in surah.ayat)
      for (final (start, end) in [
        ...ayah.spans,
        for (final mark in ayah.markSpans) (mark.start, mark.end),
      ])
        if (start >= 0 && end <= ayah.text.length && start < end)
          if (ayah.text.substring(start, end) case final slice
              when slice.codeUnits.any((u) => u > 0x7E))
            slice,
];

final _numberRun = RegExp(r'\d+(?:\s*,\s*\d+)+');

bool _contains(List<int> haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

String _hex(List<int> bytes) =>
    [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

/// What [message] gives away of [values] and [words], or an empty list.
List<String> _leaks(
  String message,
  List<List<int>> values,
  List<String> words,
) {
  final leaks = <String>[];
  if (message.codeUnits.any((u) => u < 0x20 || u > 0x7E)) {
    leaks.add('a character outside printable ASCII');
  }
  final lower = message.toLowerCase();
  for (final (index, value) in values.indexed) {
    if (value.isEmpty) continue;
    if (message.contains(utf8.decode(value, allowMalformed: true))) {
      leaks.add('stored value $index');
    }
    for (var i = 0; i + 4 <= value.length; i++) {
      if (lower.contains(_hex(value.sublist(i, i + 4)))) {
        leaks.add('stored value $index, bytes $i to ${i + 3} in hex');
        break;
      }
    }
  }
  for (final match in _numberRun.allMatches(message)) {
    final numbers = [
      for (final part in match[0]!.split(',')) int.parse(part.trim()),
    ];
    if (numbers.length < 3 || numbers.any((n) => n > 255)) continue;
    for (final (index, value) in values.indexed) {
      if (_contains(value, numbers)) {
        leaks.add('stored value $index, bytes as decimals');
      }
    }
  }
  for (final (index, word) in words.indexed) {
    if (message.contains(word)) leaks.add('non-ASCII word $index');
  }
  return leaks;
}

void main() {
  late Directory root;

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('problem_messages');
  });
  tearDownAll(() => root.delete(recursive: true));

  var builds = 0;

  /// Every message verification and the checks give for [pack], including
  /// those of a check that fails or throws.
  Future<List<String>> messagesOf(SyntheticPack pack) async {
    final loaded = await PackUnderTest.load(pack.directory.path);
    addTearDown(loaded.close);
    final messages = <String>[
      if (loaded.verification case Failure(:final error)) '$error',
    ];
    for (final check in packChecks.values) {
      try {
        messages.addAll(await check(loaded));
      } on TestFailure catch (failure) {
        messages.add(failure.message ?? '');
      } on Object catch (error) {
        messages.add('$error');
      }
    }
    return messages;
  }

  void expectNoLeaks(SyntheticPack pack, List<String> messages) {
    final values = _storedValues(pack);
    final words = _nonAsciiSlices(pack);
    final leaks = [
      for (final (index, message) in messages.indexed)
        for (final leak in _leaks(message, values, words))
          'message $index: $leak',
    ];
    // Only the indexes and kinds of leaks are printed, never the message.
    expect(leaks, isEmpty);
  }

  test('the leak search finds a stored value, a word, decimals and hex', () {
    final values = [utf8.encode('Synthetic \u{E9} value')];
    final words = ['\u{E9}'];
    expect(_leaks('it holds Synthetic \u{E9} value', values, words), [
      'a character outside printable ASCII',
      'stored value 0',
      'non-ASCII word 0',
    ]);
    expect(_leaks('bytes [83, 121, 110, 116]', values, words), [
      'stored value 0, bytes as decimals',
    ]);
    expect(_leaks('bytes 53796E74', values, words), [
      'stored value 0, bytes 0 to 3 in hex',
    ]);
    expect(
      _leaks('surah 2: ayat numbered (1, 2, 3, 5), not 1 to 4', values, words),
      isEmpty,
    );
  });

  test('the checks find nothing in a pack without a fault', () async {
    final pack = await buildSyntheticPack(
      root,
      surahs: formatSyntheticSurahs,
      id: 'fault-${builds++}',
    );
    expect(await messagesOf(pack), isEmpty);
  });

  for (final fault in SyntheticFault.values) {
    test(
      'the checks name no stored text of a pack with ${fault.name}',
      () async {
        final pack = await buildSyntheticPack(
          root,
          fault: fault,
          surahs: formatSyntheticSurahs,
          id: 'fault-${builds++}',
        );
        final messages = await messagesOf(pack);
        expect(messages, isNotEmpty, reason: 'the fault was not reported');
        expectNoLeaks(pack, messages);
      },
    );
  }

  test('the checks name no stored text of a pack whose spans overlap after '
      'the first surah, or whose divisions are out of order', () async {
    final second = defaultSyntheticSurahs[1];
    final pack = await buildSyntheticPack(
      root,
      id: 'fault-${builds++}',
      surahs: [
        defaultSyntheticSurahs[0],
        SyntheticSurah(
          name: second.name,
          revelationPlace: second.revelationPlace,
          revelationOrder: second.revelationOrder,
          ayat: [
            ...second.ayat.take(2),
            SyntheticAyah(
              second.ayat[2].text,
              words: const [(0, 9), (5, 14), (15, 21)],
            ),
          ],
        ),
        defaultSyntheticSurahs[2],
      ],
      divisions: [
        for (final d in defaultSyntheticDivisions)
          if (d.kind == 'page' && d.number == 4)
            const SyntheticDivision('page', 4, 1, 1)
          else
            d,
      ],
    );
    final messages = await messagesOf(pack);
    expect(messages, isNotEmpty);
    expectNoLeaks(pack, messages);
  });

  test('the checks name no stored text of a pack with letters between or in '
      'marks, a word without a letter, or marks out of place', () async {
    final pack = await buildSyntheticPack(
      root,
      id: 'fault-${builds++}',
      surahs: withAyat(formatSyntheticSurahs, 3, const [
        SyntheticAyah('\u{646}\u{635} \u{62A}\u{62C}', words: [(0, 2)]),
        SyntheticAyah(
          '\u{646}\u{635} \u{62A}\u{62C}',
          words: [(0, 2)],
          marks: [(afterWord: 1, start: 3, end: 5)],
        ),
        SyntheticAyah('\u{646}\u{635} \u{6D6}\u{6D7}', words: [(0, 2), (3, 5)]),
        SyntheticAyah(
          '\u{646} \u{1F600} \u{6D6}',
          words: [(0, 1)],
          marks: [
            (afterWord: 0, start: 2, end: 3),
            (afterWord: 1, start: 2, end: 6),
          ],
        ),
      ]),
    );
    final messages = await messagesOf(pack);
    for (final kind in [
      'the gap',
      'holds the letter',
      'holds no letter',
      'has after_word',
      'splits a surrogate pair',
      'span [',
    ]) {
      expect(messages, anyElement(contains(kind)), reason: kind);
    }
    expectNoLeaks(pack, messages);
  });

  test('the checks name no stored text of a pack with another font', () async {
    final pack = await buildSyntheticPack(root, id: 'fault-${builds++}');
    final manifest =
        jsonDecode(await pack.manifestFile.readAsString())
            as Map<String, Object?>;
    manifest['font'] = {
      'family': 'Synthetic Font',
      'version': '9.999',
      'sha256': sha256.convert(utf8.encode('synthetic font')).toString(),
    };
    await pack.manifestFile.writeAsString(jsonEncode(manifest));
    final messages = await messagesOf(pack);
    expect(messages, isNotEmpty);
    expectNoLeaks(pack, messages);
  });

  test('a text drawn or given with other bytes is reported by length, '
      'digest and offset only', () async {
    final pack = await buildSyntheticPack(root, id: 'fault-${builds++}');
    final stored = utf8.encode(pack.surahs[0].ayat[3].text);
    final other = pack.surahs[1].ayat[1].text;
    final messages = [
      byteMismatch(utf8.encode(other), stored)!,
      ...drawnTextProblems(
        'hafs:1:4',
        TextSpan(
          text: other,
          children: [TextSpan(text: pack.surahs[0].ayat[0].text)],
        ),
        TextSpan(text: other),
        stored,
      ),
      ...drawnTextProblems(
        'hafs:1:4',
        const TextSpan(),
        TextSpan(text: other),
        stored,
      ),
    ];
    expect(messages, hasLength(6));
    expect(
      messages.first,
      '${utf8.encode(other).length} bytes, sha256 '
      '${sha256.convert(utf8.encode(other))}, where ${stored.length} bytes, '
      'sha256 ${sha256.convert(stored)}, are stored; they differ from byte 0',
    );
    expectNoLeaks(pack, messages);
  });

  test(
    'byteMismatch is null for equal bytes and names the first difference',
    () {
      final a = utf8.encode('Synthetic abc');
      expect(byteMismatch(a, [...a]), isNull);
      expect(
        byteMismatch(utf8.encode('Synthetic abd'), a),
        endsWith('they differ from byte 12'),
      );
      expect(
        byteMismatch(utf8.encode('Synthetic ab'), a),
        endsWith('they differ from byte 12'),
      );
    },
  );
}
