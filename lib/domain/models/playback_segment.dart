import 'quran_address.dart';

/// Where a segment's audio comes from, always one of the plan's recitation's
/// own files (`AU-24`).
sealed class PlaybackSource {
  const PlaybackSource();
}

/// The recitation's file for one ayah.
final class AyahFile extends PlaybackSource {
  const AyahFile(this.ayah);

  final QuranAddress ayah;

  @override
  bool operator ==(Object other) => other is AyahFile && other.ayah == ayah;

  @override
  int get hashCode => ayah.hashCode;

  @override
  String toString() => 'AyahFile($ayah)';
}

/// The recitation's whole file for one surah.
final class SurahFile extends PlaybackSource {
  const SurahFile(this.surah);

  final int surah;

  @override
  bool operator ==(Object other) => other is SurahFile && other.surah == surah;

  @override
  int get hashCode => surah.hashCode;

  @override
  String toString() => 'SurahFile($surah)';
}

/// Part of the recitation's file for one surah, between boundaries read from
/// its timing data.
final class SurahClip extends PlaybackSource {
  SurahClip(this.surah, this.start, this.end) {
    if (start.isNegative || end <= start) {
      throw ArgumentError('clip $start to $end');
    }
  }

  final int surah;
  final Duration start;
  final Duration end;

  @override
  bool operator ==(Object other) =>
      other is SurahClip &&
      other.surah == surah &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(surah, start, end);

  @override
  String toString() => 'SurahClip($surah, $start, $end)';
}

/// The recitation's separate basmala file.
final class BasmalaFile extends PlaybackSource {
  const BasmalaFile();

  @override
  bool operator ==(Object other) => other is BasmalaFile;

  @override
  int get hashCode => (BasmalaFile).hashCode;

  @override
  String toString() => 'BasmalaFile';
}

/// The recitation's separate isti'adha file.
final class IstiadhaFile extends PlaybackSource {
  const IstiadhaFile();

  @override
  bool operator ==(Object other) => other is IstiadhaFile;

  @override
  int get hashCode => (IstiadhaFile).hashCode;

  @override
  String toString() => 'IstiadhaFile';
}

enum SegmentKind { istiadha, basmala, ayah, surah }

/// One timed piece of a plan.
final class PlaybackSegment {
  const PlaybackSegment({
    required this.kind,
    required this.address,
    required this.source,
    required this.repeat,
    this.silenceAfter = Duration.zero,
    this.endsPage = false,
    this.endsSurah = false,
  });

  final SegmentKind kind;

  /// The ayah heard; for a basmala or isti'adha, the ayah it comes before;
  /// for a whole surah, its first ayah.
  final QuranAddress address;
  final PlaybackSource source;

  /// Which hearing of its repeat unit this is, from 1.
  final int repeat;
  final Duration silenceAfter;

  /// Whether its ayah is the last of a page or of a surah of the edition.
  /// A whole surah ends its surah; its page ends are unknown.
  final bool endsPage;
  final bool endsSurah;

  PlaybackSegment withSilenceAfter(Duration silence) => PlaybackSegment(
    kind: kind,
    address: address,
    source: source,
    repeat: repeat,
    silenceAfter: silence,
    endsPage: endsPage,
    endsSurah: endsSurah,
  );

  @override
  bool operator ==(Object other) =>
      other is PlaybackSegment &&
      other.kind == kind &&
      other.address == address &&
      other.source == source &&
      other.repeat == repeat &&
      other.silenceAfter == silenceAfter &&
      other.endsPage == endsPage &&
      other.endsSurah == endsSurah;

  @override
  int get hashCode => Object.hash(
    kind,
    address,
    source,
    repeat,
    silenceAfter,
    endsPage,
    endsSurah,
  );

  @override
  String toString() =>
      '${kind.name} $address #$repeat $source'
      '${silenceAfter > Duration.zero ? ' +$silenceAfter' : ''}';
}
