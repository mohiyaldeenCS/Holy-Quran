import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/recitation_download.dart';
import 'package:holyquran/domain/models/recitation_target.dart';
import 'package:holyquran/ui/features/resources/view_models/pack_row_state.dart';

/// What a scope row downloads (`AU-13`).
enum ScopeKind { whole, surah, juz }

/// The two lists a recitation's scopes are shown in.
enum ScopeTab { surahs, juz }

enum ScopeStatus {
  available,
  downloading,

  /// Held back until a network the job may use is up.
  waiting,
  downloaded,
}

/// One thing of a recitation that can be downloaded: the whole, a surah or
/// a juz, at the quality chosen.
final class ScopeRowState {
  const ScopeRowState({
    required this.kind,
    required this.number,
    required this.selection,
    required this.key,
    required this.totalBytes,
    required this.missingBytes,
    required this.status,
    this.progress = 0,
    this.waitingForWifi = false,
    this.failure,
  });

  final ScopeKind kind;

  /// The surah or juz number; 0 for the whole.
  final int number;
  final RecitationSelection selection;
  final String key;
  final int totalBytes;

  /// What is not on the device yet. The size shown before starting.
  final int missingBytes;
  final ScopeStatus status;

  /// From 0 to 1 while downloading.
  final double progress;
  final bool waitingForWifi;
  final RecitationDownloadFailure? failure;

  /// Some of it is on the device and some is not.
  bool get partial => missingBytes > 0 && missingBytes < totalBytes;
}

/// One listed recitation of the resource manager: its pack row and, once
/// the pack is installed and read, the scopes it can be downloaded in.
final class RecitationBlockState {
  const RecitationBlockState({
    required this.recitation,
    required this.pack,
    this.qualities = const [],
    this.quality,
    this.tab = ScopeTab.surahs,
    this.whole,
    this.surahs = const [],
    this.juz = const [],
  });

  final CatalogueRecitation recitation;
  final PackRowState pack;
  final List<int> qualities;
  final int? quality;
  final ScopeTab tab;
  final ScopeRowState? whole;
  final List<ScopeRowState> surahs;
  final List<ScopeRowState> juz;

  String get id => recitation.id;

  /// Whether the scopes are known, which they are once the pack is read.
  bool get ready => whole != null;

  /// Several qualities to choose from (`AU-14`).
  bool get choosesQuality => qualities.length > 1;

  List<ScopeRowState> get rows => tab == ScopeTab.surahs ? surahs : juz;
}
