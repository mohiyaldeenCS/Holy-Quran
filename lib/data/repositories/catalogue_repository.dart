import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/catalogue.dart';
import '../../utils/result.dart';
import '../models/catalogue_json.dart';
import '../services/catalogue_service.dart';
import '../services/download_service.dart';
import '../services/manifest_signature.dart';

/// The signed catalogue of packs and recitations (D-109,
/// docs/PACK_CATALOGUE.md). Listeners hear when [catalogue] changes. The
/// packs' states on this device are `resourcesOf` the catalogue and the
/// installer.
abstract interface class CatalogueRepository implements Listenable {
  /// The last catalogue accepted, fetched or kept on the device; null until
  /// one is.
  Catalogue? get catalogue;

  /// Fetches the catalogue and, once it is accepted, serves and keeps it.
  /// When it cannot be fetched or is refused, the [CatalogueFailure] is
  /// returned and the last catalogue accepted is served, read from the
  /// device if none was read yet.
  Future<Result<Catalogue>> refresh();
}

/// [CatalogueRepository] over HTTPS from [_address], with its signature at
/// the same address followed by `.sig`, checked by [_verifier] with the
/// policy of D-108: a valid signature is accepted, an invalid one refused,
/// and one that could not be checked accepted only when [_acceptUnchecked].
final class RemoteCatalogueRepository extends ChangeNotifier
    implements CatalogueRepository {
  RemoteCatalogueRepository({
    required this._address,
    required this._service,
    required this._openStore,
    required this._verifier,
    required this._policy,
    required this._acceptUnchecked,
  });

  final Uri _address;
  final CatalogueService _service;
  final Future<CatalogueStore> Function() _openStore;
  final ManifestSignatureVerifier _verifier;
  final UrlPolicy _policy;
  final bool _acceptUnchecked;

  Catalogue? _catalogue;
  Future<Result<Catalogue>>? _refreshing;
  bool _disposed = false;

  @override
  Catalogue? get catalogue => _catalogue;

  Uri get _signatureAddress => _address.replace(path: '${_address.path}.sig');

  @override
  Future<Result<Catalogue>> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<Result<Catalogue>> _refresh() async {
    final fetched = await _fetch();
    switch (fetched) {
      case Ok(value: (:final bytes, :final signature, :final catalogue)):
        _serve(catalogue);
        await _keep(bytes, signature);
        return Ok(catalogue);
      case Failure(:final error):
        if (_catalogue == null) {
          if (await _kept() case final kept?) _serve(kept);
        }
        return Failure(error);
    }
  }

  Future<Result<_Accepted>> _fetch() async {
    final Uint8List bytes;
    switch (await _service.fetch(_address, _policy)) {
      case Ok(:final value):
        bytes = value;
      case Failure(:final error):
        return Failure(_unreachable(_address, error));
    }
    final Uint8List? signature;
    switch (await _service.fetch(_signatureAddress, _policy)) {
      case Ok(:final value):
        signature = value;
      case Failure(error: UnexpectedStatus(statusCode: 404)):
        signature = null;
      case Failure(:final error):
        return Failure(_unreachable(_signatureAddress, error));
    }
    return switch (await _accept(bytes, signature)) {
      Ok(value: final catalogue) => Ok((
        bytes: bytes,
        signature: signature,
        catalogue: catalogue,
      )),
      Failure(:final error) => Failure(error),
    };
  }

  /// The catalogue in [bytes], when its [signature] passes the policy, it
  /// parses, and every URL in it passes the download policy.
  Future<Result<Catalogue>> _accept(
    Uint8List bytes,
    Uint8List? signature,
  ) async {
    switch (await _verifier.verify(manifest: bytes, signature: signature)) {
      case SignatureCheck.valid:
        break;
      case SignatureCheck.invalid:
        return const Failure(CatalogueSignatureRejected());
      case SignatureCheck.notChecked when !_acceptUnchecked:
        return const Failure(CatalogueSignatureNotChecked());
      case SignatureCheck.notChecked:
        break;
    }
    final parsed = parseCatalogue(bytes);
    if (parsed case Ok(value: final catalogue)) {
      for (final pack in catalogue.packs) {
        for (final url in pack.urls) {
          if (!_policy.allows(url)) {
            return Failure(
              CatalogueRejected(
                'pack ${pack.id} names a URL not allowed: $url',
              ),
            );
          }
        }
      }
    }
    return parsed;
  }

  /// The catalogue kept on the device, checked as a fetched one is; null
  /// when none is kept or it does not pass.
  Future<Catalogue?> _kept() async {
    try {
      final kept = await (await _openStore()).read();
      if (kept == null) return null;
      return switch (await _accept(kept.catalogue, kept.signature)) {
        Ok(:final value) => value,
        Failure() => null,
      };
    } on Exception {
      return null;
    }
  }

  Future<void> _keep(Uint8List bytes, Uint8List? signature) async {
    try {
      await (await _openStore()).write(bytes, signature);
    } on Exception {
      // Unkept, the catalogue is fetched again at the next refresh; only
      // offline use loses it.
    }
  }

  void _serve(Catalogue catalogue) {
    _catalogue = catalogue;
    if (!_disposed) notifyListeners();
  }

  static CatalogueFailure _unreachable(Uri url, Exception error) =>
      switch (error) {
        UrlRefused(:final url) => CatalogueRejected('URL not allowed: $url'),
        _ => CatalogueUnreachable(url, '$error'),
      };

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

typedef _Accepted = ({
  Uint8List bytes,
  Uint8List? signature,
  Catalogue catalogue,
});
