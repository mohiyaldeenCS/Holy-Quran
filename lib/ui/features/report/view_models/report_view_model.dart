import 'package:flutter/foundation.dart';

import 'package:holyquran/data/repositories/pack_install_repository.dart';
import 'package:holyquran/data/repositories/quran_index_repository.dart';
import 'package:holyquran/data/services/mail_service.dart';
import 'package:holyquran/domain/models/installed_pack.dart';
import 'package:holyquran/domain/models/pack_text.dart';
import 'package:holyquran/domain/models/quran_address.dart';
import 'package:holyquran/utils/result.dart';

/// What an error report names (O-17, D-127): the ayah, and for an entry its
/// pack, version and source. D-127 sends it as a prepared message in the
/// user's mail app.
@immutable
final class ErrorReport {
  const ErrorReport({
    required this.address,
    this.packId,
    this.packVersion,
    this.sourceName,
  });

  final QuranAddress address;
  final String? packId;
  final int? packVersion;
  final String? sourceName;

  @override
  bool operator ==(Object other) =>
      other is ErrorReport &&
      other.address == address &&
      other.packId == packId &&
      other.packVersion == packVersion &&
      other.sourceName == sourceName;

  @override
  int get hashCode => Object.hash(address, packId, packVersion, sourceName);

  /// The message's lines: the address (`hafs:2:255`), never the ayah's
  /// text, then for an entry its pack, version and source apart by
  /// [separator].
  String messageBody(String separator) => [
    '$address',
    if (packId case final packId?)
      [packId, ?packVersion?.toString(), ?sourceName].join(separator),
  ].join('\r\n');
}

/// The installed pack of a reported entry, as its manifest names it.
@immutable
final class ReportedPack {
  const ReportedPack({
    required this.id,
    required this.version,
    required this.sourceName,
  });

  final String id;
  final int version;

  /// The manifest's first source; null when it lists none.
  final String? sourceName;
}

/// The «أبلغ عن خطأ» sheet's state: the ayah at [address] by its surah's
/// name from the index, and the installed pack [packId] when the report is
/// about one of its entries. A part whose data is missing is null. The
/// report is sent to [recipient] through [mail]; without both it cannot be.
final class ReportViewModel extends ChangeNotifier {
  ReportViewModel({
    required this.address,
    this.packId,
    this._index,
    this._packs,
    this._mail,
    this._recipient,
  }) {
    _packs?.addListener(notifyListeners);
  }

  final QuranAddress address;
  final String? packId;
  final QuranIndexRepository? _index;
  final PackInstallRepository? _packs;
  final MailService? _mail;
  final String? _recipient;
  bool _notOpened = false;
  bool _disposed = false;

  bool get canSend => _mail != null && _recipient != null;

  /// The last [send] found no mail app to open.
  bool get notOpened => _notOpened;

  /// Opens the mail app with the report under [subject], its lines apart as
  /// [ErrorReport.messageBody] puts them.
  Future<void> send({
    required String subject,
    required String separator,
  }) async {
    final mail = _mail;
    final recipient = _recipient;
    if (mail == null || recipient == null) return;
    final result = await mail.compose(
      MailDraft(
        to: recipient,
        subject: subject,
        body: report.messageBody(separator),
      ),
    );
    if (_disposed) return;
    _notOpened = result is Failure;
    notifyListeners();
  }

  /// Null unless the index is of the address's riwaya and holds the ayah.
  PackText? get surahName {
    final index = _index;
    if (index == null || index.riwaya != address.riwaya) return null;
    for (final surah in index.surahs) {
      if (surah.number == address.surah && address.ayah <= surah.ayahCount) {
        return surah.name;
      }
    }
    return null;
  }

  ReportedPack? get pack {
    final installed = _installed;
    if (installed == null) return null;
    final sources = installed.manifest.sources;
    return ReportedPack(
      id: installed.id,
      version: installed.version,
      sourceName: sources.isEmpty ? null : sources.first.name,
    );
  }

  ErrorReport get report {
    final pack = this.pack;
    return ErrorReport(
      address: address,
      packId: pack?.id,
      packVersion: pack?.version,
      sourceName: pack?.sourceName,
    );
  }

  InstalledPack? get _installed {
    final packId = this.packId;
    if (packId == null) return null;
    for (final installed in _packs?.installed ?? const <InstalledPack>[]) {
      if (installed.id == packId) return installed;
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    _packs?.removeListener(notifyListeners);
    super.dispose();
  }
}
