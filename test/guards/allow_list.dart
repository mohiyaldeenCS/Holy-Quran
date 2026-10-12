import 'dart:convert';
import 'dart:io';

/// One file of an allow-list folder (test/guards/allow/README.md): its
/// [target] on line 1, its [decision] on line 2, and the lines after.
typedef AllowEntry = ({
  String file,
  String target,
  String decision,
  List<String> rest,
});

/// Thrown with every problem of a folder, one `file: problem` per line.
final class AllowListError extends Error {
  AllowListError(this.folder, this.problems);

  final String folder;
  final List<String> problems;

  @override
  String toString() => 'Allow-list $folder:\n${problems.join('\n')}';
}

final _fileName = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)+\.txt$');
const _decisionKey = 'decision: ';
final _decision = RegExp(r'^decision: D-\d{3}$');

final _decisionRow = RegExp(r'^\| (D-\d{3}) \|', multiLine: true);

final _decisions = {
  for (final row in _decisionRow.allMatches(
    File('docs/DECISIONS.md').readAsStringSync(),
  ))
    row[1]!,
};

/// Reads the entries of [folder], sorted by file name. A folder that does not
/// exist holds no entries, since Git keeps no empty folder.
List<AllowEntry> readAllowEntries(String folder) {
  final directory = Directory(folder);
  if (!directory.existsSync()) return const [];
  final problems = <String>[];
  final entries = <AllowEntry>[];
  final files = directory.listSync().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final item in files) {
    final name = item.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    if (item is! File) {
      problems.add('$name: not a file');
      continue;
    }
    if (!_fileName.hasMatch(name)) {
      problems.add('$name: not named <task>-<what>.txt');
      continue;
    }
    final String text;
    try {
      text = utf8.decode(item.readAsBytesSync());
    } on FormatException {
      problems.add('$name: not UTF-8');
      continue;
    }
    // A Windows checkout may turn line ends into CRLF.
    final unix = text.replaceAll('\r\n', '\n');
    final lines = unix.endsWith('\n')
        ? unix.substring(0, unix.length - 1).split('\n')
        : unix.split('\n');
    final problem = switch (lines) {
      _ when lines.any((l) => l.trim() != l || l.isEmpty) =>
        'empty line or surrounding spaces',
      [_] => 'no decision line',
      [_, final decision, ...] when !_decision.hasMatch(decision) =>
        'line 2 is not "decision: D-xxx"',
      [_, final decision, ...]
          when !_decisions.contains(decision.substring(_decisionKey.length)) =>
        '${decision.substring(_decisionKey.length)} is not in docs/DECISIONS.md',
      _ => null,
    };
    if (problem != null) {
      problems.add('$name: $problem');
      continue;
    }
    entries.add((
      file: name,
      target: lines[0],
      decision: lines[1].substring(_decisionKey.length),
      rest: lines.sublist(2),
    ));
  }
  final seen = <String, String>{};
  for (final entry in entries) {
    final first = seen.putIfAbsent(entry.target, () => entry.file);
    if (first != entry.file) {
      problems.add('${entry.file}: ${entry.target} also listed in $first');
    }
  }
  if (problems.isNotEmpty) throw AllowListError(folder, problems);
  return entries;
}

final _segment = RegExp(r'^[A-Za-z0-9_.-]+$');
final _globSegment = RegExp(r'^[A-Za-z0-9_.*-]*\*[A-Za-z0-9_.*-]*$');

/// The paths a folder of entries allows. Each target is a file, a folder
/// ending in `/` that covers everything under it, or a file name pattern
/// whose last segment holds `*`, standing for any characters but `/`.
final class PathAllowList {
  PathAllowList._(this.targets);

  /// Loads [folder]; throws [AllowListError] on a malformed entry, a target
  /// that does not exist or matches no file, or a target listed twice.
  /// Patterns are refused unless [allowPatterns]: a pattern grants no
  /// permission only where listing more files makes the guard stricter.
  factory PathAllowList.load(String folder, {bool allowPatterns = false}) {
    final entries = readAllowEntries(folder);
    final problems = [
      for (final entry in entries)
        if (_pathProblem(entry, allowPatterns: allowPatterns)
            case final problem?)
          '${entry.file}: ${entry.target} $problem',
    ];
    if (problems.isNotEmpty) throw AllowListError(folder, problems);
    return PathAllowList._([for (final e in entries) e.target]);
  }

  /// The targets, in file-name order of their entries.
  final List<String> targets;

  bool allows(String path) => targets.any((target) => covers(target, path));

  static bool covers(String entry, String path) {
    if (entry.endsWith('/')) return path.startsWith(entry);
    if (!entry.contains('*')) return path == entry;
    return _glob(entry).hasMatch(path);
  }

  static RegExp _glob(String entry) =>
      RegExp('^${entry.split('*').map(RegExp.escape).join('[^/]*')}\$');

  static String? _pathProblem(AllowEntry entry, {required bool allowPatterns}) {
    if (entry.rest.length > 1) return 'has more than three lines';
    final target = entry.target;
    final isFolder = target.endsWith('/');
    final segments =
        (isFolder ? target.substring(0, target.length - 1) : target).split('/');
    final last = segments.removeLast();
    final wellFormed =
        segments.every(_isPlainSegment) &&
        (_isPlainSegment(last) ||
            (allowPatterns && !isFolder && _globSegment.hasMatch(last)));
    if (!wellFormed) return 'is not a relative path';
    if (isFolder) {
      return Directory(target).existsSync() ? null : 'does not exist';
    }
    if (!target.contains('*')) {
      return File(target).existsSync() ? null : 'does not exist';
    }
    final parent = Directory(segments.join('/'));
    final matches =
        parent.existsSync() &&
        parent.listSync().whereType<File>().any(
          (file) =>
              covers(target, '${parent.path}/${file.uri.pathSegments.last}'),
        );
    return matches ? null : 'matches no file';
  }

  static bool _isPlainSegment(String segment) =>
      _segment.hasMatch(segment) && segment != '.' && segment != '..';
}

final _packagePrefix = RegExp(r'^package:([a-z0-9_]+)/$');

/// The `package:<name>/` prefixes a folder of entries allows. Each package
/// must resolve, through `.dart_tool/package_config.json`.
Set<String> loadPackageAllowList(String folder) {
  final entries = readAllowEntries(folder);
  final config =
      jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
          as Map<String, Object?>;
  final known = {
    for (final package in config['packages']! as List<Object?>)
      (package! as Map<String, Object?>)['name'],
  };
  final problems = [
    for (final entry in entries)
      if (_packageProblem(entry, known) case final problem?)
        '${entry.file}: ${entry.target} $problem',
  ];
  if (problems.isNotEmpty) throw AllowListError(folder, problems);
  return {for (final entry in entries) entry.target};
}

String? _packageProblem(AllowEntry entry, Set<Object?> known) {
  if (entry.rest.length > 1) return 'has more than three lines';
  final name = _packagePrefix.firstMatch(entry.target)?[1];
  if (name == null) return 'is not package:<name>/';
  return known.contains(name) ? null : 'does not resolve';
}
