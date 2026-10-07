import 'quran_address.dart';

/// Why a pack, or text from it, was refused. [pack] is its id or directory.
sealed class PackFailure implements Exception {
  const PackFailure(this.pack);

  final String pack;
}

final class ManifestUnreadable extends PackFailure {
  const ManifestUnreadable(super.pack, this.reason);

  final String reason;

  @override
  String toString() => 'ManifestUnreadable($pack): $reason';
}

final class SignatureRejected extends PackFailure {
  const SignatureRejected(super.pack);

  @override
  String toString() => 'SignatureRejected($pack)';
}

final class UnsupportedPackFormat extends PackFailure {
  const UnsupportedPackFormat(super.pack, this.formatVersion);

  /// Null when the manifest names no readable version.
  final int? formatVersion;

  @override
  String toString() => 'UnsupportedPackFormat($pack): version $formatVersion';
}

final class FileHashMismatch extends PackFailure {
  const FileHashMismatch(super.pack, this.file);

  final String file;

  @override
  String toString() => 'FileHashMismatch($pack): $file';
}

final class SurahHashMismatch extends PackFailure {
  const SurahHashMismatch(super.pack, this.surah);

  final int surah;

  @override
  String toString() => 'SurahHashMismatch($pack): surah $surah';
}

final class TextEncodingRejected extends PackFailure {
  const TextEncodingRejected(super.pack, this.at);

  final QuranAddress at;

  @override
  String toString() => 'TextEncodingRejected($pack): $at';
}

final class AddressNotInPack extends PackFailure {
  const AddressNotInPack(super.pack, this.address);

  final QuranAddress address;

  @override
  String toString() => 'AddressNotInPack($pack): $address';
}

final class PackDisabled extends PackFailure {
  const PackDisabled(super.pack);

  @override
  String toString() => 'PackDisabled($pack)';
}
