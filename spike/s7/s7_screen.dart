import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:holyquran/data/repositories/pack_quran_text_repository.dart';
import 'package:holyquran/domain/models/surah_info.dart';
import 'package:holyquran/ui/core/theme/theme_context.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/surah_name.dart';
import 'package:holyquran/utils/result.dart';

import '../s1/measure/text_checks.dart' show openVerifiedPack;
import '../s1/render/spike_surah_text.dart';
import '../s1/s1_screen.dart' show S1Environment, describeError;
import 's7_record.dart';
import 's7_session.dart';

// The S7 entry: the pack S1 prepared, a surah to test on, or synthetic
// pages alone. Status lines hold numbers, ids and addresses only (D-072).

/// S1 saves the prepared pack's directory here (`s1_screen.dart`).
File _s1PackFile(Directory storage) => File('${storage.path}/s1-pack.json');

/// The S7 gesture test (PRD §7.4, D-095). It reads the pack that S1
/// prepared through [environment], as S1's screens do; with none, only
/// page mode opens. One [S7Record] covers every session opened from here.
class S7Screen extends StatefulWidget {
  const S7Screen({this.environment = S1Environment.device, super.key});

  static const routeName = '/s7';

  final S1Environment environment;

  @override
  State<S7Screen> createState() => _S7ScreenState();
}

class _S7ScreenState extends State<S7Screen> {
  final _record = S7Record();
  PackQuranTextRepository? _text;
  List<SurahInfo> _infos = const [];
  String? _status;
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  @override
  void dispose() {
    _text?.close();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final storage = await widget.environment.storage();
      final file = _s1PackFile(storage);
      final directory = await file.exists()
          ? (jsonDecode(await file.readAsString())
                    as Map<String, Object?>)['directory']
                as String?
          : null;
      if (directory == null || !await Directory(directory).exists()) {
        _status = 'No prepared pack: prepare the text in S1';
        return;
      }
      final opened = await openVerifiedPack(directory);
      final result = await opened.text.surahs();
      if (result case Failure(:final error)) {
        opened.text.close();
        throw StateError('surahs failed: $error');
      }
      final infos = (result as Ok<List<SurahInfo>>).value;
      if (!mounted) {
        opened.text.close();
        return;
      }
      _text = opened.text;
      _infos = infos;
      _status =
          'Verified pack ${opened.verified.manifest.id} '
          'v${opened.verified.manifest.version}';
    } on Object catch (e) {
      _error = describeError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _session(SurahInfo? info) async {
    setState(() => _busy = true);
    S7Surah? surah;
    try {
      if (info != null) {
        surah = (
          text: await readSpikeSurahText(_text!, info.number),
          name: info.name,
        );
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => S7Session(
          surah: surah,
          record: _record,
          storage: widget.environment.storage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('S7 gestures')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_busy) const LinearProgressIndicator(),
          for (final (line, colour) in [
            (_status, null),
            (_error, colors.error),
          ])
            if (line != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space4,
                  vertical: AppSpacing.space1,
                ),
                child: Text(line, style: TextStyle(color: colour)),
              ),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  title: const Text('Page mode only'),
                  subtitle: const Text('$s7PageCount synthetic pages'),
                  onTap: _busy ? null : () => _session(null),
                ),
                for (final info in _infos)
                  ListTile(
                    key: ValueKey('surah ${info.number}'),
                    leading: Text('${info.number}'),
                    title: s7Arabic(
                      context,
                      SurahName(
                        info.name,
                        style: AppTextStyles.body.copyWith(color: colors.ink),
                      ),
                    ),
                    subtitle: Text('${info.ayahCount} ayat'),
                    onTap: _busy ? null : () => _session(info),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
