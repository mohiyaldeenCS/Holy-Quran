import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/domain/models/verified_pack.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/quran_text.dart';
import 'package:holyquran/utils/result.dart';
import 'package:path_provider/path_provider.dart';

import 'measure/frame_stats.dart';
import 'measure/process_age.dart';
import 'measure/text_checks.dart';
import 'render/page_blocks_v2.dart';
import 'render/spike_surah_text.dart';
import 'render/surah_list_v1.dart';
import 'render/surah_text_block.dart';
import 'text/device_text.dart';

// The S1 device screens. Quran text reaches the screen only through the
// render widgets and QuranText; every status, error and JSON holds numbers,
// digests, addresses and U+XXXX code points only (D-072).

const _fontAsset = 'assets/fonts/AmiriQuran-Regular.ttf';

/// Logical pixels per second of the scripted scroll: steady, about a
/// screen height every half second.
const _scrollSpeed = 1500.0;
const _scrollRuns = 3;

/// Profile and release builds report frame timings at least once a second;
/// waiting this long before and after a measured action keeps other frames
/// out of it.
const _flush = Duration(seconds: 2);

const _keptColdStarts = 10;
const _gutter = AppSpacing.space4;

/// Where the S1 screens get the pack, the font and their files: the
/// device's by default, a synthetic pack's in tests.
final class S1Environment {
  const S1Environment({
    required this.prepare,
    required this.storage,
    required this.font,
  });

  static const device = S1Environment(
    prepare: prepareDeviceTanzilPack,
    storage: s1Storage,
    font: _bundledQuranFont,
  );

  /// Fetches, converts and verifies the pack; returns its directory.
  final Future<String> Function() prepare;
  final Future<Directory> Function() storage;
  final Future<Uint8List> Function() font;
}

Future<Directory> s1Storage() async =>
    Directory('${(await getApplicationSupportDirectory()).path}/spike');

Future<Uint8List> _bundledQuranFont() async {
  final data = await rootBundle.load(_fontAsset);
  return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
}

File _packFile(Directory storage) => File('${storage.path}/s1-pack.json');
File _armFile(Directory storage) =>
    File('${storage.path}/s1-cold-start-armed.json');
File _runsFile(Directory storage) =>
    File('${storage.path}/s1-cold-starts.json');

/// The saved position a cold start opens at.
typedef ColdStartArm = ({int surah, int ayah});

/// The armed cold start in [storage], or null when none is armed.
Future<ColdStartArm?> readColdStartArm(Directory storage) async {
  final file = _armFile(storage);
  if (!await file.exists()) return null;
  final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
  return (surah: json['surah']! as int, ayah: json['ayah']! as int);
}

/// A launch with a cold start armed: the position and the process ages
/// taken so far, in order, to which the screen adds its own.
final class ColdStartLaunch {
  ColdStartLaunch({required this.arm, required this.ages});

  final ColdStartArm arm;
  final Map<String, Duration?> ages;
}

/// The spike's own errors name steps, addresses and digests only; any other
/// error is shown by its type, since its text might hold Quran text.
String describeError(Object error) => switch (error) {
  StateError(:final message) => message,
  FormatException(:final message) => message,
  _ => '${error.runtimeType}',
};

typedef _Pack = ({
  VerifiedPack verified,
  PackQuranTextRepository text,
  List<SurahInfo> infos,
});

Future<_Pack> _open(String directory) async {
  final opened = await openVerifiedPack(directory);
  final infos = switch (await opened.text.surahs()) {
    Ok(:final value) => value,
    Failure(:final error) => throw StateError('surahs failed: $error'),
  };
  return (verified: opened.verified, text: opened.text, infos: infos);
}

Future<String?> _preparedDirectory(Directory storage) async {
  final file = _packFile(storage);
  if (!await file.exists()) return null;
  final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
  final directory = json['directory']! as String;
  return await Directory(directory).exists() ? directory : null;
}

int _longestSurah(List<SurahInfo> infos) =>
    infos.reduce((a, b) => b.ayahCount > a.ayahCount ? b : a).number;

String get _buildMode => kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

Future<void> _copy(BuildContext context, Object? json) async {
  await Clipboard.setData(
    ClipboardData(text: const JsonEncoder.withIndent(' ').convert(json)),
  );
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('JSON copied')));
  }
}

/// The app's Arabic localizations and right-to-left direction for the
/// widgets that draw the text, under the spike's English, left-to-right UI.
Widget _arabic(BuildContext context, Widget child) => Localizations.override(
  context: context,
  locale: const Locale('ar'),
  delegates: AppLocalizations.localizationsDelegates,
  child: child,
);

/// The RD-06 page-mark slot: an outline only, since the mark's look is not
/// in the identity yet (D-071).
Widget _pageMarkSlot(BuildContext context, int page) => DecoratedBox(
  decoration: BoxDecoration(border: Border.all(color: context.colors.line)),
);

/// Collects the engine's frame timings while [action] runs and for [_flush]
/// after it.
Future<List<FrameTiming>> _timingsOf(Future<void> Function() action) async {
  final timings = <FrameTiming>[];
  void collect(List<FrameTiming> batch) => timings.addAll(batch);
  SchedulerBinding.instance.addTimingsCallback(collect);
  try {
    await action();
    await Future<void>.delayed(_flush);
  } finally {
    SchedulerBinding.instance.removeTimingsCallback(collect);
  }
  return timings;
}

double _ms(Duration d) => d.inMicroseconds / 1000;

class S1Screen extends StatefulWidget {
  const S1Screen({this.environment = S1Environment.device, super.key});

  final S1Environment environment;

  @override
  State<S1Screen> createState() => _S1ScreenState();
}

class _S1ScreenState extends State<S1Screen> {
  _Pack? _pack;
  String? _busy;
  String? _error;
  Map<String, Object?>? _integrity;
  List<Object?> _coldStarts = const [];
  final _armSurah = TextEditingController();
  final _armAyah = TextEditingController();

  S1Environment get _env => widget.environment;

  @override
  void initState() {
    super.initState();
    unawaited(_run('Opening the pack prepared earlier', _reopen));
  }

  @override
  void dispose() {
    _pack?.text.close();
    _armSurah.dispose();
    _armAyah.dispose();
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
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _reopen() async {
    final storage = await _env.storage();
    final runs = _runsFile(storage);
    if (await runs.exists()) {
      _coldStarts = jsonDecode(await runs.readAsString()) as List<Object?>;
    }
    final directory = await _preparedDirectory(storage);
    if (directory != null) _use(await _open(directory));
  }

  Future<void> _prepare() async {
    final directory = await _env.prepare();
    final storage = await _env.storage();
    await storage.create(recursive: true);
    await _packFile(
      storage,
    ).writeAsString(jsonEncode({'directory': directory}), flush: true);
    _use(await _open(directory));
  }

  void _use(_Pack pack) {
    if (!mounted) {
      pack.text.close();
      return;
    }
    _pack?.text.close();
    final longest = _longestSurah(pack.infos);
    final ayat = pack.infos.firstWhere((s) => s.number == longest).ayahCount;
    setState(() {
      _pack = pack;
      _integrity = null;
      _armSurah.text = '$longest';
      _armAyah.text = '${(ayat + 1) ~/ 2}';
    });
  }

  Future<void> _measureIntegrity(double readerWidth) async {
    final pack = _pack!;
    final longest = _longestSurah(pack.infos);
    final subset = [
      for (final info in pack.infos)
        if ({1, 2, 18, 112, longest}.contains(info.number)) info.number,
    ];
    final widths = {...measureWidths, readerWidth}.toList()..sort();
    final measurement = TextPackMeasurement();
    var done = 0;
    await measurement.run(
      verified: pack.verified,
      text: pack.text,
      ttf: await _env.font(),
      surahNumbers: subset,
      widths: widths,
      progress: (surah) {
        done++;
        if (mounted) {
          setState(
            () => _busy =
                'Integrity: surah $surah measured, $done of ${subset.length}',
          );
        }
      },
    );
    if (!mounted) return;
    final view = View.of(context);
    measurement.results['device'] = {
      'readerWidth': readerWidth,
      'devicePixelRatio': view.devicePixelRatio,
      'systemTextScale': MediaQuery.textScalerOf(context).scale(100) / 100,
      'subset': subset,
    };
    if (mounted) setState(() => _integrity = measurement.results);
  }

  Future<void> _read() async {
    final pack = _pack!;
    final number = await Navigator.of(context).push<int>(
      MaterialPageRoute(builder: (_) => _SurahPicker(infos: pack.infos)),
    );
    if (number == null || !mounted) return;
    await _run('Reading surah $number', () async {
      final surah = await readSpikeSurahText(pack.text, number);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => S1ReaderScreen(surah: surah)),
      );
    });
  }

  Future<void> _scrollTest() async {
    final pack = _pack!;
    final number = _longestSurah(pack.infos);
    await _run('Reading surah $number', () async {
      final surah = await readSpikeSurahText(pack.text, number);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => S1ScrollTestScreen(surah: surah),
        ),
      );
    });
  }

  Future<void> _arm() async {
    final pack = _pack!;
    final surah = int.tryParse(_armSurah.text);
    final ayah = int.tryParse(_armAyah.text);
    final info = pack.infos.where((s) => s.number == surah).firstOrNull;
    if (info == null || ayah == null || ayah < 1 || ayah > info.ayahCount) {
      throw StateError('no such ayah in the pack: $surah:$ayah');
    }
    final storage = await _env.storage();
    await storage.create(recursive: true);
    await _armFile(
      storage,
    ).writeAsString(jsonEncode({'surah': surah, 'ayah': ayah}), flush: true);
    exit(0);
  }

  Future<void> _clearColdStarts() async {
    final file = _runsFile(await _env.storage());
    if (await file.exists()) await file.delete();
    if (mounted) setState(() => _coldStarts = const []);
  }

  @override
  Widget build(BuildContext context) {
    final pack = _pack;
    final readerWidth = MediaQuery.sizeOf(context).width - 2 * _gutter;
    return Scaffold(
      appBar: AppBar(title: const Text('S1 surah rendering')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy case final busy?) ...[
            const LinearProgressIndicator(),
            _Line(busy),
          ],
          if (_error case final error?)
            _Line(error, color: context.colors.error),
          Expanded(child: _sections(context, pack, readerWidth)),
        ],
      ),
    );
  }

  Widget _sections(BuildContext context, _Pack? pack, double readerWidth) {
    final idle = _busy == null;
    final ready = idle && pack != null;
    return ListView(
      padding: const EdgeInsets.all(_gutter),
      children: [
        Text('Build: $_buildMode'),
        const _Heading('1. Text'),
        Text(
          pack == null
              ? 'No pack yet.'
              : 'Verified pack ${pack.verified.manifest.id} '
                    'v${pack.verified.manifest.version}: '
                    '${pack.verified.manifest.counts.surahs} surahs, '
                    '${pack.verified.manifest.counts.ayat} ayat, text.sqlite '
                    '${pack.verified.manifest.files.single.sha256}',
        ),
        _Actions([
          FilledButton(
            onPressed: idle
                ? () => _run(
                    'Fetching, converting and verifying the text',
                    _prepare,
                  )
                : null,
            child: const Text('Prepare text'),
          ),
        ]),
        const _Heading('2. Integrity'),
        Text(
          'Surahs 1, 2, 18, 112 and the one with the most ayat, at 360, 412 '
          'and ${readerWidth.toStringAsFixed(1)} wide, 1.0x and 2.0x.',
        ),
        _Actions([
          FilledButton(
            onPressed: ready
                ? () => _run(
                    'Integrity: reading the pack',
                    () => _measureIntegrity(readerWidth),
                  )
                : null,
            child: const Text('Run integrity'),
          ),
          if (_integrity != null)
            OutlinedButton(
              onPressed: () => _copy(context, _integrity),
              child: const Text('Copy JSON'),
            ),
        ]),
        if (_integrity case final results?) _IntegritySummary(results),
        const _Heading('3. Read'),
        const Text(
          'V1 or V2, tap words, text scale 1.0x to 2.0x. "System" uses the '
          "phone's font size.",
        ),
        _Actions([
          FilledButton(
            onPressed: ready ? _read : null,
            child: const Text('Pick a surah'),
          ),
        ]),
        const _Heading('4. Scroll test'),
        Text(
          'The surah with the most ayat, top to bottom at '
          '${_scrollSpeed.toInt()} px/s, V1 then V2, $_scrollRuns runs '
          'each.',
        ),
        _Actions([
          FilledButton(
            onPressed: ready ? _scrollTest : null,
            child: const Text('Run scroll test'),
          ),
        ]),
        const _Heading('5. Text-size change'),
        const Text(
          'In the reader: "Measure 1.0x to 2.0x" times the frames that lay '
          'the surah out again.',
        ),
        const _Heading('6. Cold start'),
        const Text(
          '"Arm and exit" saves the position and closes the app. Then '
          'force-stop it in Settings and open it from its icon.',
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _armSurah,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Surah'),
              ),
            ),
            const SizedBox(width: _gutter),
            Expanded(
              child: TextField(
                controller: _armAyah,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ayah'),
              ),
            ),
          ],
        ),
        _Actions([
          FilledButton(
            onPressed: ready ? () => _run('Arming', _arm) : null,
            child: const Text('Arm and exit'),
          ),
          if (_coldStarts.isNotEmpty) ...[
            OutlinedButton(
              onPressed: () => _copy(context, _coldStarts),
              child: const Text('Copy runs JSON'),
            ),
            OutlinedButton(
              onPressed: idle ? _clearColdStarts : null,
              child: const Text('Clear runs'),
            ),
          ],
        ]),
        for (final run in _coldStarts.cast<Map<String, Object?>>())
          Text(_coldStartLine(run)),
      ],
    );
  }
}

String _coldStartLine(Map<String, Object?> run) {
  final ages = run['agesMs']! as Map<String, Object?>;
  return '${run['at']}: ${run['surah']}:${run['ayah']}, saved ayah shown at '
      '${ages['savedAyahShown'] ?? '?'} ms';
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.space5),
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

class _IntegritySummary extends StatelessWidget {
  const _IntegritySummary(this.results);

  final Map<String, Object?> results;

  @override
  Widget build(BuildContext context) {
    final surahs = results['surahs']! as List<Map<String, Object?>>;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Problems: ${jsonEncode(results['problemCounts'])}'),
        Text('Elapsed ${results['elapsedMs']} ms'),
        for (final surah in surahs)
          for (final run in surah['runs']! as List<Map<String, Object?>>)
            Text(
              'Surah ${surah['surah']} ${run['width']}'
              '/${run['scale']}x: ${run['lines']} lines, '
              '${(run['fingerprint']! as String).substring(0, 16)}, '
              'V2 same as V1: '
              '${(run['v2'] as Map<String, Object?>?)?['sameLineStartsAsV1'] ?? '-'}, '
              'problems ${jsonEncode(run['problems'])}',
            ),
      ],
    );
  }
}

class _SurahPicker extends StatelessWidget {
  const _SurahPicker({required this.infos});

  final List<SurahInfo> infos;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pick a surah')),
    body: ListView.builder(
      itemCount: infos.length,
      itemBuilder: (context, i) {
        final info = infos[i];
        return ListTile(
          key: ValueKey('surah ${info.number}'),
          leading: Text('${info.number}'),
          title: QuranText(
            info.name,
            size: QuranTextSize.compact,
            align: QuranTextAlign.start,
          ),
          subtitle: Text('${info.ayahCount} ayat'),
          onTap: () => Navigator.of(context).pop(info.number),
        );
      },
    ),
  );
}

enum SpikeLayout { v1, v2 }

/// One surah in V1 or V2 under [scale] (null: the system's text scale).
class _SurahView extends StatelessWidget {
  const _SurahView({
    required this.surah,
    required this.layout,
    required this.scale,
    this.pageMarks = true,
    this.highlighted = const {},
    this.onWordTap,
    this.controller,
    this.blockKey,
    super.key,
  });

  final SpikeSurahText surah;
  final SpikeLayout layout;
  final double? scale;
  final bool pageMarks;
  final Set<QuranAddress> highlighted;
  final ValueChanged<QuranAddress>? onWordTap;
  final ScrollController? controller;
  final Key? blockKey;

  @override
  Widget build(BuildContext context) => _arabic(
    context,
    Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: scale == null
              ? media
              : media.copyWith(textScaler: TextScaler.linear(scale!)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            child: switch (layout) {
              SpikeLayout.v1 => SurahListV1(
                surah: surah,
                highlighted: highlighted,
                onWordTap: onWordTap,
                pageMark: pageMarks ? _pageMarkSlot : null,
                pageMarkSize: measurePageMark,
                controller: controller,
                blockKey: blockKey,
              ),
              SpikeLayout.v2 => PageBlocksV2(
                surah: surah,
                highlighted: highlighted,
                onWordTap: onWordTap,
                pageMark: pageMarks ? _pageMarkSlot : null,
                pageMarkSize: measurePageMark,
                controller: controller,
              ),
            },
          ),
        );
      },
    ),
  );
}

class S1ReaderScreen extends StatefulWidget {
  const S1ReaderScreen({required this.surah, super.key});

  final SpikeSurahText surah;

  @override
  State<S1ReaderScreen> createState() => _S1ReaderScreenState();
}

class _S1ReaderScreenState extends State<S1ReaderScreen> {
  SpikeLayout _layout = SpikeLayout.v1;
  double? _scale;
  bool _pageMarks = true;
  QuranAddress? _tapped;
  bool _measuring = false;
  Map<String, Object?>? _scaleChange;
  String? _error;

  void _tap(QuranAddress word) =>
      setState(() => _tapped = word == _tapped ? null : word);

  Future<void> _measureScaleChange() async {
    setState(() {
      _measuring = true;
      _scale = 1.0;
      _scaleChange = null;
      _error = null;
    });
    try {
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(_flush);
      if (!mounted) return;
      final refreshRate = View.of(context).display.refreshRate;
      final clock = Stopwatch();
      final timings = await _timingsOf(() async {
        clock.start();
        setState(() => _scale = 2.0);
        await SchedulerBinding.instance.endOfFrame;
        clock.stop();
      });
      if (timings.isEmpty) throw StateError('no frame timings were reported');
      final first = timings.first;
      if (!mounted) return;
      setState(
        () => _scaleChange = {
          'format': 1,
          'mode': _buildMode,
          'surah': widget.surah.firstAyah.surah,
          'layout': _layout.name,
          'readerWidth': MediaQuery.sizeOf(context).width - 2 * _gutter,
          'from': 1.0,
          'to': 2.0,
          'uiThreadToEndOfFrameMs': _ms(clock.elapsed),
          'firstFrame': {
            'buildMs': _ms(first.buildDuration),
            'rasterMs': _ms(first.rasterDuration),
            'totalMs': _ms(first.totalSpan),
          },
          'frames': FrameStats.from(timings, refreshRate: refreshRate).toJson(),
        },
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _measuring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = MediaQuery.textScalerOf(context).scale(100) / 100;
    final change = _scaleChange;
    return Scaffold(
      appBar: AppBar(title: Text('Surah ${widget.surah.firstAyah.surah}')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            child: Wrap(
              spacing: AppSpacing.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<SpikeLayout>(
                  segments: const [
                    ButtonSegment(value: SpikeLayout.v1, label: Text('V1')),
                    ButtonSegment(value: SpikeLayout.v2, label: Text('V2')),
                  ],
                  selected: {_layout},
                  onSelectionChanged: _measuring
                      ? null
                      : (s) => setState(() => _layout = s.single),
                ),
                for (final scale in [null, 1.0, 1.5, 2.0])
                  ChoiceChip(
                    label: Text(
                      scale == null
                          ? 'System ${system.toStringAsFixed(2)}x'
                          : '${scale}x',
                    ),
                    selected: _scale == scale,
                    onSelected: _measuring
                        ? null
                        : (_) => setState(() => _scale = scale),
                  ),
                FilterChip(
                  label: const Text('Page-mark slots'),
                  selected: _pageMarks,
                  onSelected: _measuring
                      ? null
                      : (on) => setState(() => _pageMarks = on),
                ),
                TextButton(
                  onPressed: _measuring ? null : _measureScaleChange,
                  child: Text(
                    _measuring ? 'Measuring...' : 'Measure 1.0x to 2.0x',
                  ),
                ),
              ],
            ),
          ),
          if (_tapped case final word?)
            _Line('Tapped $word (tap it again to clear)'),
          if (_error case final error?) _Line(error),
          if (change != null)
            Row(
              children: [
                Expanded(
                  child: _Line(
                    '1.0x to 2.0x: UI thread '
                    '${(change['uiThreadToEndOfFrameMs']! as double).toStringAsFixed(1)} ms, '
                    'first frame ${jsonEncode(change['firstFrame'])}',
                  ),
                ),
                TextButton(
                  onPressed: () => _copy(context, change),
                  child: const Text('Copy JSON'),
                ),
              ],
            ),
          Expanded(
            child: _SurahView(
              key: ValueKey(_layout),
              surah: widget.surah,
              layout: _layout,
              scale: _scale,
              pageMarks: _pageMarks,
              highlighted: {?_tapped},
              onWordTap: _tap,
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: _gutter,
      vertical: AppSpacing.space1,
    ),
    child: Text(text, style: TextStyle(color: color)),
  );
}

/// Scrolls [surah] from top to bottom at [_scrollSpeed], V1 then V2,
/// [_scrollRuns] times each, and reports the frame timings of each run.
class S1ScrollTestScreen extends StatefulWidget {
  const S1ScrollTestScreen({required this.surah, super.key});

  final SpikeSurahText surah;

  @override
  State<S1ScrollTestScreen> createState() => _S1ScrollTestScreenState();
}

class _S1ScrollTestScreenState extends State<S1ScrollTestScreen> {
  SpikeLayout _layout = SpikeLayout.v1;
  ScrollController _controller = ScrollController();
  final _status = ValueNotifier('Starting');
  final List<Map<String, Object?>> _runs = [];
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_all()));
  }

  @override
  void dispose() {
    _controller.dispose();
    _status.dispose();
    super.dispose();
  }

  Future<void> _all() async {
    try {
      for (final layout in SpikeLayout.values) {
        if (!mounted) return;
        if (layout != _layout) {
          final old = _controller;
          setState(() {
            _layout = layout;
            _controller = ScrollController();
          });
          await SchedulerBinding.instance.endOfFrame;
          old.dispose();
        }
        for (var run = 1; run <= _scrollRuns; run++) {
          _status.value =
              '${layout.name.toUpperCase()} run $run of '
              '$_scrollRuns';
          final result = await _scroll();
          if (result == null) return;
          _runs.add({'layout': layout.name, 'run': run, ...result});
        }
      }
      if (mounted) setState(() => _done = true);
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  Future<Map<String, Object?>?> _scroll() async {
    final controller = _controller;
    controller.jumpTo(0);
    await SchedulerBinding.instance.endOfFrame;
    await Future<void>.delayed(_flush);
    if (!mounted) return null;
    final refreshRate = View.of(context).display.refreshRate;
    final clock = Stopwatch();
    var distance = 0.0;
    final timings = await _timingsOf(() async {
      final done = Completer<void>();
      var lastMax = -1.0;
      var stalled = 0;
      final ticker = Ticker((elapsed) {
        if (!mounted || !controller.hasClients) {
          if (!done.isCompleted) done.complete();
          return;
        }
        final position = controller.position;
        final max = position.maxScrollExtent;
        final target = _ms(elapsed) / 1000 * _scrollSpeed;
        // V2 learns its extent as it builds blocks; the run ends when the
        // end stops moving away.
        if (target < max) {
          stalled = 0;
          controller.jumpTo(target);
        } else {
          stalled = max == lastMax ? stalled + 1 : 0;
          controller.jumpTo(max);
          if (stalled >= 5 && !done.isCompleted) done.complete();
        }
        lastMax = max;
      });
      clock.start();
      unawaited(ticker.start());
      await done.future;
      clock.stop();
      distance = controller.hasClients ? controller.position.pixels : 0;
      ticker.dispose();
    });
    if (timings.isEmpty) throw StateError('no frame timings were reported');
    return {
      'surah': widget.surah.firstAyah.surah,
      'distancePx': distance.roundToDouble(),
      'durationMs': clock.elapsedMilliseconds,
      'speedPxPerS': _scrollSpeed,
      'stats': FrameStats.from(timings, refreshRate: refreshRate).toJson(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final results = {
      'format': 1,
      'mode': _buildMode,
      'readerWidth': media.size.width - 2 * _gutter,
      'textScale': media.textScaler.scale(100) / 100,
      'refreshRate': View.of(context).display.refreshRate,
      'runs': _runs,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('S1 scroll test')),
      body: _done || _error != null
          ? ListView(
              padding: const EdgeInsets.all(_gutter),
              children: [
                if (_error case final error?) Text(error),
                OutlinedButton(
                  onPressed: () => _copy(context, results),
                  child: const Text('Copy JSON'),
                ),
                for (final run in _runs) Text(_scrollLine(run)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ValueListenableBuilder(
                  valueListenable: _status,
                  builder: (context, status, _) => _Line(status),
                ),
                Expanded(
                  child: _SurahView(
                    key: ValueKey(_layout),
                    surah: widget.surah,
                    layout: _layout,
                    scale: null,
                    controller: _controller,
                  ),
                ),
              ],
            ),
    );
  }
}

String _scrollLine(Map<String, Object?> run) {
  final stats = run['stats']! as Map<String, Object?>;
  final total = stats['total']! as Map<String, Object?>;
  return '${run['layout']} run ${run['run']}: ${stats['frames']} frames at '
      '${stats['refreshRate']} Hz, total p50 ${total['p50']} p99 '
      '${total['p99']} max ${total['max']} ms, over 16.7 ms '
      '${stats['over16ms']}, over 32 ms ${stats['over32ms']}';
}

/// Opens the armed position as fast as it can, from a launch with the
/// marker set, and records the process age at each step.
class S1ColdStartScreen extends StatefulWidget {
  const S1ColdStartScreen({
    required this.launch,
    this.environment = S1Environment.device,
    super.key,
  });

  final ColdStartLaunch launch;
  final S1Environment environment;

  @override
  State<S1ColdStartScreen> createState() => _S1ColdStartScreenState();
}

class _S1ColdStartScreenState extends State<S1ColdStartScreen> {
  final _controller = ScrollController();
  final _blockKey = GlobalKey();
  PackQuranTextRepository? _text;
  SpikeSurahText? _surah;
  bool _placed = false;
  Map<String, Object?>? _run;
  String? _error;

  ColdStartArm get _arm => widget.launch.arm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mark('firstFrame'));
    unawaited(_start());
  }

  @override
  void dispose() {
    _controller.dispose();
    _text?.close();
    super.dispose();
  }

  void _mark(String step) => widget.launch.ages[step] = processAge();

  Future<void> _start() async {
    try {
      final storage = await widget.environment.storage();
      final directory =
          await _preparedDirectory(storage) ??
          (throw StateError('no prepared pack: prepare the text in S1'));
      final opened = await openVerifiedPack(directory);
      _text = opened.text;
      _mark('packVerified');
      final surah = await readSpikeSurahText(opened.text, _arm.surah);
      _mark('surahRead');
      if (!mounted) return;
      setState(() => _surah = surah);
      WidgetsBinding.instance.addPostFrameCallback((_) => _laidOut());
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  void _laidOut() {
    _mark('laidOut');
    final block =
        _blockKey.currentContext?.findRenderObject() as RenderSurahTextBlock?;
    final surah = _surah!;
    final top = block?.topOf(
      QuranAddress(surah.firstAyah.riwaya, _arm.surah, _arm.ayah),
    );
    if (top == null) {
      setState(() => _error = 'ayah ${_arm.surah}:${_arm.ayah} not laid out');
      return;
    }
    _controller.jumpTo(math.min(top, _controller.position.maxScrollExtent));
    setState(() => _placed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mark('savedAyahShown');
      unawaited(_save());
    });
  }

  Future<void> _save() async {
    if (!mounted) return;
    final media = MediaQuery.of(context);
    final ages = widget.launch.ages;
    final run = <String, Object?>{
      'format': 1,
      'mode': _buildMode,
      'at': DateTime.now().toUtc().toIso8601String(),
      'surah': _arm.surah,
      'ayah': _arm.ayah,
      'layout': SpikeLayout.v1.name,
      'readerWidth': media.size.width - 2 * _gutter,
      'textScale': media.textScaler.scale(100) / 100,
      'refreshRate': View.of(context).display.refreshRate,
      'agesMs': {
        for (final MapEntry(:key, :value) in ages.entries)
          key: value == null ? null : _ms(value),
      },
    };
    setState(() => _run = run);
    try {
      final file = _runsFile(await widget.environment.storage());
      final runs = await file.exists()
          ? jsonDecode(await file.readAsString()) as List<Object?>
          : <Object?>[];
      runs.add(run);
      final kept = runs.sublist(math.max(0, runs.length - _keptColdStarts));
      await file.writeAsString(jsonEncode(kept), flush: true);
      if (mounted) setState(() => _run = {...run, 'kept': kept.length});
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  Future<void> _disarm() async {
    final file = _armFile(await widget.environment.storage());
    if (await file.exists()) await file.delete();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copyRuns() async {
    final file = _runsFile(await widget.environment.storage());
    final runs = await file.exists()
        ? jsonDecode(await file.readAsString())
        : <Object?>[];
    if (mounted) await _copy(context, runs);
  }

  @override
  Widget build(BuildContext context) {
    final surah = _surah;
    final run = _run;
    return Scaffold(
      appBar: AppBar(title: const Text('S1 cold start')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Line('Armed at ${_arm.surah}:${_arm.ayah}'),
          if (_error case final error?) _Line(error),
          if (run != null) ...[
            for (final MapEntry(:key, :value)
                in (run['agesMs']! as Map<String, Object?>).entries)
              _Line('$key: ${value ?? 'n/a'} ms'),
            if (run['kept'] case final kept?) _Line('$kept runs kept'),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _gutter),
            child: Wrap(
              spacing: AppSpacing.space2,
              children: [
                OutlinedButton(
                  onPressed: _copyRuns,
                  child: const Text('Copy runs JSON'),
                ),
                OutlinedButton(
                  onPressed: () => exit(0),
                  child: const Text('Exit for the next run'),
                ),
                OutlinedButton(onPressed: _disarm, child: const Text('Disarm')),
              ],
            ),
          ),
          Expanded(
            child: surah == null
                ? const SizedBox.shrink()
                : Offstage(
                    offstage: !_placed,
                    child: _SurahView(
                      surah: surah,
                      layout: SpikeLayout.v1,
                      scale: null,
                      controller: _controller,
                      blockKey: _blockKey,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
