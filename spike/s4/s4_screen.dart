import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/utils/result.dart';

import '../../testing/packs/synthetic_pack.dart'
    show amiriQuranFontPath, textFileName;
import '../s1/measure/text_checks.dart';
import '../s1/s1_screen.dart';
import 'ayah_widget_face.dart';
import 'native_shaping_probe.dart';
import 'shaping_compare.dart';
import 'widget_bridge.dart';
import 'widget_fit.dart';
import 'widget_publisher.dart';
import 'widget_slots.dart';
import 'widget_test_pack.dart';

// The S4 device screen (D-094): publishes a week of ayah faces to the
// home-screen widget, asks the launcher to pin it, compares the native and
// Flutter layouts of synthetic text, and keeps every result in one file. Its
// chrome and its file hold numbers, addresses, digests and enum names only;
// Quran text reaches the screen only through AyahWidgetFace.

const _days = 7;

/// Candidates read from the start address: enough for both faces' week even
/// when most of them are too long for a face (WG-03).
const _candidateWindow = 120;

/// widget_fit's first size, the largest a face draws.
const _probeFontSize = 28.0;

const _gutter = AppSpacing.space4;

const _resultsFileName = 's4-results.json';
const _resultsFormat = 1;

/// The pinned SHA-256 of the device pack's text.sqlite, as S1 prepared it.
const _pinnedPackSha256 = String.fromEnvironment('SPIKE_TANZIL_PACK_SHA256');

File _resultsFile(Directory storage) =>
    File('${storage.path}/$_resultsFileName');

/// How a widget tap reached the app.
enum WidgetLaunch {
  /// It started the process.
  cold,

  /// The app was running; the tap came as a new intent.
  warm,

  /// The process and its engine lived on after the activity was closed; the
  /// tap started a new activity on them.
  reattached,
}

/// What a widget tap opened, and how the tap reached the app.
typedef WidgetTap = ({QuranAddress address, WidgetLaunch launch});

/// Why the screen uses the synthetic pack instead of S1's device pack.
enum SyntheticReason {
  noPack,
  pinMissing,
  pinMismatch,
  verifyFailed,
  readFailed,
}

/// The ayat [WidgetPublisher] may take, from a pack verified as the app
/// verifies it.
final class WidgetCandidates {
  WidgetCandidates({
    required this.textSha256,
    required this.read,
    required this.close,
    this.synthetic,
  });

  /// Null for the device pack.
  final SyntheticReason? synthetic;

  /// The verified manifest's SHA-256 of text.sqlite.
  final String textSha256;

  /// Up to `count` ayat in address order from surah `surah`, ayah `ayah`.
  final Future<List<WidgetAyah>> Function(int surah, int ayah, int count) read;
  final void Function() close;
}

/// Where the S4 screen gets the widget plugin, the probe, the packs, the
/// font and its file: the device's by default, fakes in tests.
final class S4Environment {
  const S4Environment({
    required this.bridge,
    required this.probe,
    required this.storage,
    required this.packDirectory,
    required this.synthetic,
    required this.font,
    this.pinnedPackSha256 = _pinnedPackSha256,
    this.render = renderFacePng,
    this.now = DateTime.now,
  });

  static const device = S4Environment(
    bridge: HomeWidgetBridge.open,
    probe: MethodChannelShapingProbe(),
    storage: s1Storage,
    packDirectory: _s1PackDirectory,
    synthetic: _deviceSyntheticPack,
    font: _bundledQuranFont,
  );

  final Future<WidgetBridge> Function() bridge;
  final ShapingProbe probe;

  /// `<support>/spike`, beside S1's files and S3's log.
  final Future<Directory> Function() storage;

  /// The pack S1 prepared, or null when there is none.
  final Future<String?> Function() packDirectory;

  /// The fallback pack, built on demand.
  final Future<WidgetTestPack> Function() synthetic;
  final Future<Uint8List> Function() font;

  /// S1's pack is used only if its text.sqlite has this SHA-256.
  final String pinnedPackSha256;
  final FaceRenderer render;
  final DateTime Function() now;
}

Future<Uint8List> _bundledQuranFont() async {
  final data = await rootBundle.load(amiriQuranFontPath);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

/// The directory S1 recorded in `s1-pack.json`, if it is still there: S1
/// keeps its own reader private.
Future<String?> _s1PackDirectory() async {
  final file = File('${(await s1Storage()).path}/s1-pack.json');
  if (!await file.exists()) return null;
  final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
  final directory = json['directory']! as String;
  return await Directory(directory).exists() ? directory : null;
}

/// The synthetic pack built on the device. Its writer reads the font from a
/// path relative to the working directory, which on a device is `/`; so the
/// bundled font is written under a work directory that is the working
/// directory while the pack is built, as S5 builds its packs.
Future<WidgetTestPack> _deviceSyntheticPack() async {
  final work = Directory('${(await s1Storage()).path}/s4-synthetic');
  if (await work.exists()) await work.delete(recursive: true);
  final font = File('${work.path}/$amiriQuranFontPath');
  await font.parent.create(recursive: true);
  await font.writeAsBytes(await _bundledQuranFont(), flush: true);
  final previous = Directory.current;
  Directory.current = work;
  try {
    return await loadWidgetTestPack(Directory('${work.path}/pack'));
  } finally {
    Directory.current = previous;
  }
}

/// S1's pack if it verifies and its text.sqlite has the pinned SHA-256,
/// else the synthetic pack and the reason.
Future<WidgetCandidates> _openCandidates(S4Environment env) async {
  final directory = await env.packDirectory();
  if (directory == null) {
    return _syntheticCandidates(env, SyntheticReason.noPack);
  }
  if (env.pinnedPackSha256.isEmpty) {
    return _syntheticCandidates(env, SyntheticReason.pinMissing);
  }
  final ({VerifiedPack verified, PackQuranTextRepository text}) opened;
  final List<SurahInfo> infos;
  try {
    opened = await openVerifiedPack(directory);
  } on StateError {
    return _syntheticCandidates(env, SyntheticReason.verifyFailed);
  }
  final text = opened.text;
  final sha = opened.verified.manifest.files
      .where((file) => file.name == textFileName)
      .firstOrNull
      ?.sha256;
  if (sha == null || sha != env.pinnedPackSha256) {
    text.close();
    return _syntheticCandidates(env, SyntheticReason.pinMismatch);
  }
  switch (await text.surahs()) {
    case Ok(:final value):
      infos = value;
    case Failure():
      text.close();
      return _syntheticCandidates(env, SyntheticReason.readFailed);
  }

  Future<List<WidgetAyah>> read(int surah, int ayah, int count) async {
    final ayat = <WidgetAyah>[];
    for (final info in infos.where((info) => info.number >= surah)) {
      final first = info.number == surah ? ayah : 1;
      for (var n = first; n <= info.ayahCount; n++) {
        if (ayat.length == count) return ayat;
        final address = QuranAddress(text.riwaya, info.number, n);
        final ayahText = switch (await text.ayahText(address)) {
          Ok(:final value) => value,
          Failure() => throw StateError('$address did not read'),
        };
        ayat.add((address: address, ayah: ayahText, surahName: info.name));
      }
    }
    return ayat;
  }

  return WidgetCandidates(textSha256: sha, read: read, close: text.close);
}

Future<WidgetCandidates> _syntheticCandidates(
  S4Environment env,
  SyntheticReason reason,
) async {
  final pack = await env.synthetic();
  return WidgetCandidates(
    synthetic: reason,
    textSha256: pack.textSha256,
    read: (surah, ayah, count) async => pack.ayat
        .where(
          (a) =>
              a.address.surah > surah ||
              (a.address.surah == surah && a.address.ayah >= ayah),
        )
        .take(count)
        .toList(),
    close: pack.close,
  );
}

String get _buildMode => kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

String _fixed(double value) => value.toStringAsFixed(2);

/// A cause by its type, or a platform error by its code: their messages
/// might hold anything.
String _describe(Object error) => switch (error) {
  PlatformException(:final code) => 'PlatformException($code)',
  _ => describeError(error),
};

/// [json] encoded, refused unless every character is ASCII: the file holds
/// no Arabic code point, so no Quran text (D-094).
String encodeS4Results(Map<String, Object?> json) {
  final encoded = const JsonEncoder.withIndent(' ').convert(json);
  if (encoded.codeUnits.any((unit) => unit > 0x7f)) {
    throw StateError('the S4 results hold a non-ASCII character');
  }
  return encoded;
}

/// The results file in [storage], empty when there is none. A file that
/// does not decode as an object is moved aside, kept for the record, so
/// that the screen can go on.
Map<String, Object?> _readResults(Directory storage) {
  final file = _resultsFile(storage);
  if (!file.existsSync()) return {};
  try {
    final json = jsonDecode(file.readAsStringSync());
    if (json is Map<String, Object?>) return json;
  } on FormatException {
    // Moved aside below.
  }
  file.renameSync(
    '${file.path}.unreadable-${DateTime.now().millisecondsSinceEpoch}',
  );
  return {};
}

/// Appends [entry] to the list [key] of the results file in [storage] and
/// returns the whole file as written. Synchronous, so that two S4 screens (a
/// tap opens one over another) never interleave a read and a write; written
/// beside and renamed over the old file, so a killed process leaves the old
/// file whole.
Map<String, Object?> _append(
  Directory storage,
  String key,
  Map<String, Object?> entry,
) {
  storage.createSync(recursive: true);
  final results = <String, Object?>{
    ..._readResults(storage),
    'spike': 'S4',
    'format': _resultsFormat,
  };
  results[key] = [if (results[key] case final List<Object?> old) ...old, entry];
  final file = _resultsFile(storage);
  File('${file.path}.partial')
    ..writeAsStringSync(encodeS4Results(results), flush: true)
    ..renameSync(file.path);
  return results;
}

/// [slotAt]'s rule on the slots as the results file keeps them, without
/// their image paths: the address of the last slot whose day has started,
/// else of the first.
String? _shownAt(List<Object?> slots, int nowMs) {
  String? first;
  String? shown;
  for (final slot in slots) {
    if (slot case {
      SlotField.address: final String address,
      SlotField.slotStartMs: final int start,
    }) {
      first ??= address;
      if (start <= nowMs) shown = address;
    }
  }
  return shown ?? first;
}

Map<String, Object?>? _last(Map<String, Object?> results, String key) =>
    switch (results[key]) {
      final List<Object?> list when list.isNotEmpty =>
        list.last is Map<String, Object?>
            ? list.last! as Map<String, Object?>
            : null,
      _ => null,
    };

/// The device session's S4 test: publish, pin, the shaping probe, and the
/// tap that opened it, if one did (WG-02).
class S4Screen extends StatefulWidget {
  const S4Screen({
    this.environment = S4Environment.device,
    this.openedBy,
    super.key,
  });

  final S4Environment environment;
  final WidgetTap? openedBy;

  @override
  State<S4Screen> createState() => _S4ScreenState();
}

typedef _Preview = ({WidgetAyah ayah, double quranSize});

class _S4ScreenState extends State<S4Screen> {
  WidgetBridge? _bridge;
  WidgetCandidates? _candidates;
  String? _busy;
  String? _error;
  Map<String, Object?> _results = const {};
  final Map<WidgetFaceSize, _Preview> _previews = {};
  final _startSurah = TextEditingController(text: '1');
  final _startAyah = TextEditingController(text: '1');

  S4Environment get _env => widget.environment;

  @override
  void initState() {
    super.initState();
    unawaited(_run('Opening the pack and the results', _open));
  }

  @override
  void dispose() {
    _candidates?.close();
    _startSurah.dispose();
    _startAyah.dispose();
    super.dispose();
  }

  Future<void> _run(String what, Future<void> Function() action) async {
    setState(() {
      _busy = what;
      _error = null;
    });
    try {
      await action();
    } on Object catch (e) {
      if (mounted) setState(() => _error = _describe(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  String get _at => _env.now().toUtc().toIso8601String();

  Future<void> _open() async {
    _results = _readResults(await _env.storage());
    if (widget.openedBy case final tap?) await _recordTap(tap);
    final candidates = await _openCandidates(_env);
    if (!mounted) {
      candidates.close();
      return;
    }
    setState(() => _candidates = candidates);
    await _showPreviews();
    final bridge = await _env.bridge();
    if (mounted) setState(() => _bridge = bridge);
  }

  Future<void> _record(String key, Map<String, Object?> entry) async {
    final results = _append(await _env.storage(), key, entry);
    if (mounted) setState(() => _results = results);
  }

  /// The tapped ayah beside the one each face shows today by the last
  /// publish, if there was one: the WG-02 check.
  Future<void> _recordTap(WidgetTap tap) async {
    final shown = <String, Object?>{};
    final faces = _last(_results, 'publishes')?['faces'];
    if (faces is Map<String, Object?>) {
      for (final size in WidgetFaceSize.values) {
        if (faces[size.name] case {'slots': final List<Object?> slots}) {
          shown[size.name] = _shownAt(slots, _env.now().millisecondsSinceEpoch);
        }
      }
    }
    await _record('links', {
      'at': _at,
      'address': tap.address.toString(),
      'launch': tap.launch.name,
      'shownToday': shown,
    });
  }

  ({int surah, int ayah}) _start() {
    final surah = int.tryParse(_startSurah.text.trim());
    final ayah = int.tryParse(_startAyah.text.trim());
    if (surah == null || ayah == null || surah < 1 || ayah < 1) {
      throw StateError('the start needs a surah and an ayah number');
    }
    return (surah: surah, ayah: ayah);
  }

  Future<void> _publish(double pixelRatio) async {
    final candidates = _candidates!;
    final start = _start();
    final ayat = await candidates.read(
      start.surah,
      start.ayah,
      _candidateWindow,
    );
    if (ayat.isEmpty) {
      throw StateError('no ayah at or after ${start.surah}:${start.ayah}');
    }
    final clock = Stopwatch()..start();
    final result =
        await WidgetPublisher(
          _bridge!,
          now: _env.now,
          render: _env.render,
        ).publish(
          ayat,
          packTextSha256: candidates.textSha256,
          pixelRatio: pixelRatio,
          // Named although it is the default: the screen and the results
          // say how many days were asked for.
          // ignore: avoid_redundant_argument_values
          days: _days,
        );
    final run = <String, Object?>{
      'at': _at,
      'mode': _buildMode,
      'pack': candidates.synthetic?.name ?? 'device',
      'packTextSha256': candidates.textSha256,
      'start': ayat.first.address.toString(),
      'candidates': ayat.length,
      'pixelRatio': pixelRatio,
      'days': _days,
      'elapsedMs': clock.elapsedMilliseconds,
    };
    switch (result) {
      case Ok(value: final publication):
        run['result'] = 'ok';
        run['faces'] = {
          for (final size in WidgetFaceSize.values)
            size.name: _faceJson(publication, size),
        };
      case Failure(:final error):
        run['result'] = 'failure';
        run['failedCall'] = error is WidgetPublishFailure ? error.call : null;
        run['cause'] = _describe(
          error is WidgetPublishFailure ? error.cause : error,
        );
    }
    await _record('publishes', run);
    await _showPreviews();
  }

  /// The faces the widget shows today by the last publish, read again from
  /// the open pack if that publish used it, so that a screen opened by a
  /// widget tap shows them too.
  Future<void> _showPreviews() async {
    final candidates = _candidates;
    final run = _last(_results, 'publishes');
    final faces = run?['faces'];
    final previews = <WidgetFaceSize, _Preview>{};
    if (candidates != null &&
        run?['packTextSha256'] == candidates.textSha256 &&
        faces is Map<String, Object?>) {
      for (final size in WidgetFaceSize.values) {
        if (faces[size.name] case {'slots': final List<Object?> slots}) {
          final shown = _shownAt(slots, _env.now().millisecondsSinceEpoch);
          final address = shown == null ? null : QuranAddress.tryParse(shown);
          if (address == null) continue;
          final read = await candidates.read(address.surah, address.ayah, 1);
          final ayah = read.where((a) => a.address == address).firstOrNull;
          if (ayah == null) continue;
          final box = AyahWidgetFace.ayahBoxOf(faceSizeOf(size));
          final quranSize = fitQuranSize(ayah.ayah, box);
          if (quranSize == null) continue;
          previews[size] = (ayah: ayah, quranSize: quranSize);
        }
      }
    }
    if (!mounted) return;
    setState(
      () => _previews
        ..clear()
        ..addAll(previews),
    );
  }

  /// The slots as stored natively, less the image paths.
  Map<String, Object?> _faceJson(
    WidgetPublication publication,
    WidgetFaceSize size,
  ) {
    final slots = publication.slots[size]!;
    final skipped = publication.skipped[size]!;
    final faceSize = faceSizeOf(size);
    return {
      'width': faceSize.width,
      'height': faceSize.height,
      'renderMs': slots.fold<int>(0, (sum, slot) => sum + slot.renderMs),
      'skipped': [for (final address in skipped) address.toString()],
      'slots': [
        for (final slot in slots)
          {
            SlotField.address: slot.address,
            SlotField.slotStartMs: slot.slotStartMs,
            SlotField.packTextSha256: slot.packTextSha256,
            SlotField.lightBytes: slot.lightBytes,
            SlotField.darkBytes: slot.darkBytes,
            SlotField.lightSha256: slot.lightSha256,
            SlotField.darkSha256: slot.darkSha256,
            SlotField.renderMs: slot.renderMs,
          },
      ],
    };
  }

  Future<void> _pin() async {
    final Map<String, Object?> pin;
    try {
      pin = {'at': _at, 'supported': await _bridge!.requestPin()};
    } on Exception catch (e) {
      await _record('pins', {'at': _at, 'cause': _describe(e)});
      rethrow;
    }
    await _record('pins', pin);
  }

  Future<void> _probe() async {
    final fontSha256 = sha256.convert(await _env.font()).toString();
    final maxWidth = AyahWidgetFace.ayahBoxOf(
      faceSizeOf(WidgetFaceSize.medium),
    ).width;
    final samples = <Object?>[];
    for (final sample in ShapingSample.values) {
      final entry = <String, Object?>{'sample': sample.name};
      try {
        final native = await _env.probe.measure(
          sample,
          fontSize: _probeFontSize,
          maxWidth: maxWidth,
        );
        final flutter = measureFlutterShaping(
          sample,
          fontSize: _probeFontSize,
          maxWidth: maxWidth,
        );
        final comparison = compareShaping(
          flutter,
          native.measure,
          fontMatches: native.fontSha256 == fontSha256,
        );
        entry.addAll({
          'nativeFontSha256': native.fontSha256,
          'fontMatches': comparison.fontMatches,
          'widthDelta': comparison.widthDelta,
          'heightDelta': comparison.heightDelta,
          'lineCountDelta': comparison.lineCountDelta,
          'firstMovedLine': comparison.firstMovedLine,
          'lineWidthDeltas': comparison.lineWidthDeltas,
          'native': _measureJson(native.measure),
          'flutter': _measureJson(flutter),
        });
      } on Exception catch (e) {
        entry['cause'] = _describe(e);
      }
      samples.add(entry);
    }
    await _record('shaping', {
      'at': _at,
      'fontSize': _probeFontSize,
      'maxWidth': maxWidth,
      'assetFontSha256': fontSha256,
      'samples': samples,
    });
  }

  Map<String, Object?> _measureJson(ShapingMeasure measure) => {
    'width': measure.width,
    'height': measure.height,
    'lineCount': measure.lineCount,
    'lineStarts': measure.lineStarts,
    'lineWidths': measure.lineWidths,
  };

  /// The file as it is now: another S4 screen may have added to it.
  Future<void> _copyResults() async {
    final results = _readResults(await _env.storage());
    await Clipboard.setData(ClipboardData(text: encodeS4Results(results)));
    if (mounted) {
      setState(() => _results = results);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Results JSON copied')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('S4 home-screen widget')),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy case final busy?) ...[
          const LinearProgressIndicator(),
          _Line(busy),
        ],
        if (_error case final error?) _Line(error, color: context.colors.error),
        Expanded(child: _sections(context)),
      ],
    ),
  );

  Widget _sections(BuildContext context) {
    final idle = _busy == null;
    final candidates = _candidates;
    final ready = idle && candidates != null && _bridge != null;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final links = _results['links'];
    return ListView(
      padding: const EdgeInsets.all(_gutter),
      children: [
        Text('Build: $_buildMode, pixel ratio ${_fixed(pixelRatio)}'),
        if (widget.openedBy case final tap?)
          Text('Opened by a widget tap (${tap.launch.name}): ${tap.address}'),
        const _Heading('1. Publish'),
        Text(switch (candidates) {
          null => 'No pack open.',
          WidgetCandidates(synthetic: null) =>
            'Device pack, text.sqlite ${candidates.textSha256}',
          WidgetCandidates(synthetic: final reason?) =>
            'Synthetic pack (${reason.name}), text.sqlite '
                '${candidates.textSha256}',
        }),
        const Text(
          'The first $_days days for each face, from up to $_candidateWindow '
          'ayat in order from the start.',
        ),
        Row(
          spacing: _gutter,
          children: [
            Expanded(
              child: TextField(
                controller: _startSurah,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Start surah'),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _startAyah,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Start ayah'),
              ),
            ),
          ],
        ),
        _Actions([
          FilledButton(
            onPressed: ready
                ? () => _run('Publishing', () => _publish(pixelRatio))
                : null,
            child: const Text('Publish'),
          ),
        ]),
        if (_last(_results, 'publishes') case final run?) _PublishSummary(run),
        for (final MapEntry(key: size, value: preview) in _previews.entries)
          _FacePreviews(size: size, preview: preview),
        if (_previews.isNotEmpty)
          _Actions([
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _FaceComparison(previews: _previews),
                ),
              ),
              child: const Text('Compare at whole pixels'),
            ),
          ]),
        const _Heading('2. Pin'),
        _Actions([
          FilledButton(
            onPressed: idle && _bridge != null
                ? () => _run('Asking to pin', _pin)
                : null,
            child: const Text('Pin the widget'),
          ),
        ]),
        if (_last(_results, 'pins') case final pin?) Text(_pinLine(pin)),
        const _Heading('3. Shaping probe'),
        Text(
          'Four synthetic samples at ${_probeFontSize.toInt()} px: the '
          'native TextView minus Flutter.',
        ),
        _Actions([
          FilledButton(
            onPressed: idle ? () => _run('Probing the shaping', _probe) : null,
            child: const Text('Run the probe'),
          ),
        ]),
        if (_last(_results, 'shaping') case final shaping?)
          _ShapingSummary(shaping),
        const _Heading('4. Results'),
        const Text('spike/$_resultsFileName in the app support directory.'),
        _Actions([
          OutlinedButton(
            onPressed: _results.isEmpty ? null : _copyResults,
            child: const Text('Copy results JSON'),
          ),
        ]),
        if (links is List<Object?>)
          for (final link in links.whereType<Map<String, Object?>>())
            Text('Tap ${link['at']}: ${link['address']}, ${link['launch']}'),
      ],
    );
  }
}

String _pinLine(Map<String, Object?> pin) => switch (pin) {
  {'supported': true} => 'Pin requested at ${pin['at']}',
  {'supported': false} => 'This launcher cannot pin widgets (${pin['at']})',
  _ => 'Pin failed: ${pin['cause']}',
};

class _PublishSummary extends StatelessWidget {
  const _PublishSummary(this.run);

  final Map<String, Object?> run;

  @override
  Widget build(BuildContext context) {
    final faces = run['faces'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Published ${run['at']} from ${run['start']}: ${run['candidates']} '
          'candidates, ${run['elapsedMs']} ms in all',
        ),
        if (run['result'] == 'failure')
          Text(
            'Failed at ${run['failedCall'] ?? 'publish'}: ${run['cause']}',
            style: TextStyle(color: context.colors.error),
          ),
        if (faces is Map<String, Object?>)
          for (final size in WidgetFaceSize.values)
            if (faces[size.name] case {
              'slots': final List<Object?> slots,
              'skipped': final List<Object?> skipped,
              'renderMs': final int renderMs,
            })
              Text(
                '${size.name}: ${slots.length} slots, ${skipped.length} '
                'skipped, render $renderMs ms',
              ),
      ],
    );
  }
}

/// The first slot's face of [size], paper and night, at its logical size
/// and the device's pixel ratio, to compare with the placed widget.
class _FacePreviews extends StatelessWidget {
  const _FacePreviews({required this.size, required this.preview});

  final WidgetFaceSize size;
  final _Preview preview;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${size.name}, today ${preview.ayah.address}, '
        '${preview.quranSize.toInt()} px; square corners, the launcher '
        'rounds them',
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          spacing: _gutter,
          children: [
            for (final look in WidgetLook.values)
              AyahWidgetFace(
                ayah: preview.ayah.ayah,
                surahName: preview.ayah.surahName,
                ayahNumber: preview.ayah.address.ayah,
                quranSize: preview.quranSize,
                look: look,
                size: faceSizeOf(size),
              ),
          ],
        ),
      ),
    ],
  );
}

/// One face per page at the safe area's top left: the inset is a whole
/// number of physical pixels, so each face starts on a pixel as the
/// published image does, unlike the previews in the scrolling list.
class _FaceComparison extends StatelessWidget {
  const _FaceComparison({required this.previews});

  final Map<WidgetFaceSize, _Preview> previews;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: PageView(
      children: [
        for (final MapEntry(key: size, value: preview) in previews.entries)
          for (final look in WidgetLook.values)
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AyahWidgetFace(
                    ayah: preview.ayah.ayah,
                    surahName: preview.ayah.surahName,
                    ayahNumber: preview.ayah.address.ayah,
                    quranSize: preview.quranSize,
                    look: look,
                    size: faceSizeOf(size),
                  ),
                  _Line(
                    '${size.name} ${look.name}, ${preview.ayah.address}. '
                    'Swipe for the next face.',
                  ),
                ],
              ),
            ),
      ],
    ),
  );
}

class _ShapingSummary extends StatelessWidget {
  const _ShapingSummary(this.shaping);

  final Map<String, Object?> shaping;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Font asset ${shaping['assetFontSha256']}'),
      if (shaping['samples'] case final List<Object?> samples)
        for (final sample in samples.whereType<Map<String, Object?>>())
          Text(_sampleLine(sample)),
    ],
  );
}

String _sampleLine(Map<String, Object?> s) => switch (s) {
  {
    'widthDelta': final num width,
    'heightDelta': final num height,
    'lineCountDelta': final int lines,
    'fontMatches': final bool matches,
  } =>
    '${s['sample']}: width ${_fixed(width.toDouble())}, height '
        '${_fixed(height.toDouble())}, lines $lines, first moved line '
        '${s['firstMovedLine'] ?? 'none'}, font '
        '${matches ? 'matches' : 'differs'}',
  _ => '${s['sample']}: failed: ${s['cause']}',
};

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: _gutter),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _Actions extends StatelessWidget {
  const _Actions(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
    child: Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: children,
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: _gutter,
      vertical: AppSpacing.space2,
    ),
    child: Text(text, style: TextStyle(color: color)),
  );
}
