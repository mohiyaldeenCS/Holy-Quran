import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:holyquran/data/repositories/local_pack_repository.dart';
import 'package:holyquran/data/services/manifest_signature.dart';
import 'package:holyquran/data/services/pack_file_service.dart';
import 'package:path_provider/path_provider.dart';

import '../../testing/packs/synthetic_pack.dart';
import 'background_downloader_adapter.dart';
import 'device_packs.dart';
import 'loopback_forwarder.dart';
import 'loopback_pack_server.dart';
import 'pack_download_queue.dart';
import 'pack_store.dart';

const _packId = 'spike-s5-synthetic';
const _packBytes = 8 << 20;
const _throttle = 256 * 1024;

/// Fixed, so that a task the system re-runs after a force-stop finds the
/// server at the same URL.
const _port = 47805;

/// More than the 1 MiB the plugin needs before it keeps resume data.
const _dropAfter = 2 << 20;

/// Above any phone's free space, in MiB.
const _spaceAboveFree = 1 << 20;

/// Owns the run outside the screen, so leaving the screen neither stops a
/// download nor loses the log.
class S5Run {
  S5Run._();

  static final S5Run instance = S5Run._();

  final _changes = StreamController<void>.broadcast();
  final List<String> lines = [];
  Future<void>? _starting;
  late final Directory _base;
  File? _logFile;
  Future<void> _writes = Future.value();
  late final LoopbackPackServer _server;
  late final LoopbackForwarder _forwarder;
  late final PackStore _store;
  late final BackgroundDownloaderAdapter _adapter;
  late final PackDownloadQueue _queue;
  final Map<String, String> _lastProgress = {};
  bool ready = false;
  bool busy = false;
  bool wifiOnly = true;
  bool spaceCheck = false;
  int corruptNext = 0;
  bool dropNext = false;
  PackVersions? versions;

  Stream<void> get changes => _changes.stream;

  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    _base = Directory(
      '${(await getApplicationSupportDirectory()).path}/spike-s5',
    );
    await _base.create(recursive: true);
    final logFile = File('${_base.path}/log.txt');
    if (await logFile.exists()) {
      lines.insertAll(0, await logFile.readAsLines());
    }
    _logFile = logFile;
    log('--- start ${DateTime.now().toIso8601String()}');

    final served = Directory('${_base.path}/served');
    log('building synthetic packs of about ${_packBytes >> 20} MiB if needed');
    final font = await rootBundle.load(amiriQuranFontPath);
    for (final line in await buildDevicePacks(
      served: served,
      work: Directory('${_base.path}/font-work'),
      font: font.buffer.asUint8List(font.offsetInBytes, font.lengthInBytes),
      id: _packId,
      bytes: _packBytes,
    )) {
      log(line);
    }
    _server = await LoopbackPackServer.start(served);
    for (final version in [1, 2]) {
      _server.inject(
        _textPath(version),
        const Throttle(_throttle),
        times: null,
      );
    }
    _forwarder = await LoopbackForwarder.start(
      port: _port,
      targetPort: _server.baseUri.port,
    );
    log('serving at ${_forwarder.baseUri}, ${_throttle ~/ 1024} KiB/s');

    _store = PackStore(Directory('${_base.path}/store'));
    final recovered = await _store.recover();
    log(
      'recover: ${recovered.isEmpty ? 'nothing to do' : recovered.join('; ')}',
    );
    versions = await _store.versionsOf(_packId);

    _adapter = BackgroundDownloaderAdapter(FileDownloader(), log: log);
    await _adapter.start();
    log('space check off: "${await _adapter.requireFreeSpace(null)}"');
    _queue = PackDownloadQueue(
      downloader: _adapter,
      store: _store,
      verifier: const LocalPackRepository(
        files: PackFileService(),
        signatures: SignatureNotConfigured(),
      ),
    );
    _queue.events.listen(_onEvent);
    ready = true;
    _changed();
  }

  String _textPath(int version) => '$_packId/$version/$textFileName';

  Future<void> download(int version) async {
    final path = _textPath(version);
    if (corruptNext > 0) {
      final size = await File('${_base.path}/served/$path').length();
      _server.inject(path, CorruptByte(size ~/ 2), times: corruptNext);
      log('armed: corrupt $path x$corruptNext');
      corruptNext = 0;
    }
    if (dropNext) {
      _server.inject(path, const DropAfter(_dropAfter));
      log('armed: drop $path after $_dropAfter bytes');
      dropNext = false;
    }
    final from = _server.requests.length;
    busy = true;
    _changed();
    try {
      await _queue.enqueue(
        PackRequest(
          id: _packId,
          version: version,
          base: _forwarder.baseUri.replace(path: '/$_packId/$version/'),
          wifiOnly: wifiOnly,
        ),
      );
    } finally {
      for (final request in _server.requests.skip(from)) {
        log('server: $request');
      }
      versions = await _store.versionsOf(_packId);
      busy = false;
      _changed();
    }
  }

  Future<void> rollback() async {
    log('rollback: ${await _store.rollback(_packId)}');
    versions = await _store.versionsOf(_packId);
    _changed();
  }

  void armCorrupt() {
    corruptNext++;
    _changed();
  }

  void armDrop() {
    dropNext = true;
    _changed();
  }

  Future<void> toggleSpaceCheck() async {
    spaceCheck = !spaceCheck;
    final answer = await _adapter.requireFreeSpace(
      spaceCheck ? _spaceAboveFree : null,
    );
    log(
      'space check ${spaceCheck ? 'on, $_spaceAboveFree MiB' : 'off'}: '
      '"$answer"',
    );
    _changed();
  }

  void toggleWifiOnly() {
    wifiOnly = !wifiOnly;
    log('Wi-Fi only ${wifiOnly ? 'on' : 'off'} (applies to the next pack)');
    _changed();
  }

  void clearLog() {
    lines.clear();
    _append(null);
    _changed();
  }

  void log(String line) {
    final stamped =
        '${DateTime.now().toIso8601String().substring(11, 23)} '
        '$line';
    lines.add(stamped);
    _append(stamped);
    _changed();
  }

  /// Appends [line] to the log file, or empties the file when null; writes
  /// run one after another, in order.
  void _append(String? line) {
    final file = _logFile;
    if (file == null) return;
    _writes = _writes.then((_) async {
      try {
        await file.writeAsString(
          line == null ? '' : '$line\n',
          mode: line == null ? FileMode.write : FileMode.append,
          flush: true,
        );
      } on FileSystemException {
        // The on-screen log keeps the line; a lost file line is acceptable.
      }
    });
  }

  void _onEvent(QueueEvent event) {
    if (event is FileProgressed) {
      final progress = event.progress;
      final step = switch ((progress.received, progress.total)) {
        (final r?, final t?) when t > 0 =>
          '${progress.state.name} '
              '${r * 10 ~/ t * 10}%',
        _ => progress.state.name,
      };
      final key = '${event.request} ${event.file}';
      if (_lastProgress[key] == step) return;
      _lastProgress[key] = step;
    }
    log('$event');
  }

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
  }
}

class S5Screen extends StatefulWidget {
  const S5Screen({super.key});

  @override
  State<S5Screen> createState() => _S5ScreenState();
}

class _S5ScreenState extends State<S5Screen> {
  final S5Run _run = S5Run.instance;
  late final StreamSubscription<void> _changes;

  @override
  void initState() {
    super.initState();
    _changes = _run.changes.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(
      _run.start().catchError((Object e) => _run.log('start failed: $e')),
    );
  }

  @override
  void dispose() {
    unawaited(_changes.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    final idle = run.ready && !run.busy;
    final versions = run.versions;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const Text('S5 downloads')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              run.ready
                  ? 'Current: ${versions?.active ?? 'none'}, '
                        'previous: ${versions?.previous ?? 'none'}'
                  : 'Starting...',
            ),
            Text(
              'Wi-Fi only: ${run.wifiOnly}; space check: ${run.spaceCheck}; '
              'corrupt next: ${run.corruptNext}; drop next: ${run.dropNext}',
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: idle ? () => run.download(1) : null,
                  child: const Text('Download v1'),
                ),
                FilledButton(
                  onPressed: idle ? () => run.download(2) : null,
                  child: const Text('Update to v2'),
                ),
                OutlinedButton(
                  onPressed: idle ? run.rollback : null,
                  child: const Text('Rollback'),
                ),
                OutlinedButton(
                  onPressed: run.ready ? run.armCorrupt : null,
                  child: const Text('Corrupt next file'),
                ),
                OutlinedButton(
                  onPressed: run.ready ? run.armDrop : null,
                  child: const Text('Drop connection'),
                ),
                OutlinedButton(
                  onPressed: run.ready ? run.toggleSpaceCheck : null,
                  child: Text(
                    run.spaceCheck
                        ? 'Space check off'
                        : 'Space check above free',
                  ),
                ),
                OutlinedButton(
                  onPressed: run.toggleWifiOnly,
                  child: Text(
                    run.wifiOnly ? 'Allow mobile data' : 'Wi-Fi only',
                  ),
                ),
                OutlinedButton(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: run.lines.join('\n')),
                  ),
                  child: const Text('Copy log'),
                ),
                OutlinedButton(
                  onPressed: run.busy ? null : run.clearLog,
                  child: const Text('Clear log'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SelectableText(run.lines.reversed.take(300).join('\n')),
          ],
        ),
      ),
    );
  }
}
