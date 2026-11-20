import 'package:holyquran/domain/models/catalogue_entry.dart';
import 'package:holyquran/domain/models/recitation.dart';

/// A `Ready` recitation as the catalogue lists it, under a synthetic
/// [reciter] name that tells the setup's rows apart.
CatalogueRecitation readyRecitation(String id, String reciter) =>
    CatalogueRecitation(
      recitation: Recitation(
        id: id,
        reciter: reciter,
        riwaya: 'hafs',
        style: 'Synthetic style',
        unit: RecitationUnit.ayah,
        hasWordTiming: false,
        rightsComplete: true,
      ),
      qualities: const [64],
      packId: 'synthetic-recitation-pack',
    );

/// Two recitations, so that the setup's recitation step has a choice.
List<CatalogueRecitation> twoReadyRecitations() => [
  readyRecitation('synthetic-first', 'قارئ تجريبي أول'),
  readyRecitation('synthetic-second', 'قارئ تجريبي ثان'),
];
