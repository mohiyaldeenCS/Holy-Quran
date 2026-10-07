import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'continuity_log.dart';
import 'spike_audio_handler.dart';

Future<File> spikeLogFile() async =>
    File('${(await getApplicationSupportDirectory()).path}/spike/s3-log.jsonl');

/// Owns the run outside the screen, so leaving and reopening the screen
/// neither stops the run nor loses its log.
class S3Run {
  S3Run._(this.audio) {
    _subscriptions.add(audio.events.listen(_onEvent));
  }

  static S3Run? _instance;
  static S3Run of(SpikeAudioHandler audio) => _instance ??= S3Run._(audio);

  final SpikeAudioHandler audio;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final _changes = StreamController<void>.broadcast();
  ContinuityLogger? _logger;
  List<ContinuitySample> _samples = [];
  List<ContinuityEvent> _events = [];

  Stream<void> get changes => _changes.stream;
  bool get running => _logger?.running ?? false;

  String get report {
    final logger = _logger;
    final samples = logger?.samples ?? _samples;
    final events = logger?.events ?? _events;
    return [
      analyse(samples, trackLength: spikeTrackLength).summary,
      eventTally(events),
      'write_failures ${logger?.writeFailures ?? 0}',
    ].where((part) => part.isNotEmpty).join('\n');
  }

  Future<void> loadPrevious() async {
    if (_logger != null) return;
    final file = await spikeLogFile();
    if (!await file.exists()) return;
    final log = parseContinuityLog(await file.readAsString());
    _samples = log.samples;
    _events = log.events;
    _changes.add(null);
  }

  Future<void> start() async {
    if (running) return;
    final tone = await spikeToneFile();
    await audio.loadTone(tone);
    final logger = _logger ??= await _createLogger();
    await logger.start();
    await audio.play();
  }

  Future<void> stop() async {
    await audio.stop();
    await _logger?.stop();
  }

  Future<ContinuityLogger> _createLogger() async {
    final logger = ContinuityLogger(
      file: await spikeLogFile(),
      probe: audio.probe,
    );
    _subscriptions.add(logger.updates.listen((_) => _changes.add(null)));
    return logger;
  }

  void _onEvent(String name) {
    final logger = _logger;
    if (logger == null) return;
    logger.record(name);
    if (name == 'completed') unawaited(logger.stop());
  }
}

class S3Screen extends StatefulWidget {
  const S3Screen({super.key, required this.audio});

  final SpikeAudioHandler audio;

  @override
  State<S3Screen> createState() => _S3ScreenState();
}

class _S3ScreenState extends State<S3Screen> {
  late final S3Run _run = S3Run.of(widget.audio);
  late final StreamSubscription<void> _changes;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _changes = _run.changes.listen((_) {
      if (mounted) setState(() {});
    });
    unawaited(_run.loadPrevious());
  }

  @override
  void dispose() {
    unawaited(_changes.cancel());
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _run.report;
    final total = spikeTrackLength * spikeTrackCount;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const Text('S3 playback')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Run ${total.inMinutes} min, screen locked.'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy || _run.running
                      ? null
                      : () => _guard(_run.start),
                  child: const Text('Start run'),
                ),
                OutlinedButton(
                  onPressed: _busy || !_run.running
                      ? null
                      : () => _guard(_run.stop),
                  child: const Text('Stop run'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: report)),
                  child: const Text('Copy report'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(_run.running ? 'running' : 'stopped'),
            const SizedBox(height: 8),
            SelectableText(report),
          ],
        ),
      ),
    );
  }
}
