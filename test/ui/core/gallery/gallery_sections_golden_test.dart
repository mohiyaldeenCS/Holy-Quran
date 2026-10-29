@Tags(['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/ui/core/gallery/gallery_screen.dart';
import 'package:holyquran/ui/core/gallery/sections/audio_gallery.dart';
import 'package:holyquran/ui/core/gallery/sections/controls_gallery.dart';
import 'package:holyquran/ui/core/gallery/sections/home_share_gallery.dart';
import 'package:holyquran/ui/core/gallery/sections/mushaf_gallery.dart';
import 'package:holyquran/ui/core/gallery/sections/study_search_gallery.dart';

import '../../../../testing/golden.dart';

// Each section as the gallery draws it: 400 wide, like the M0.2 block's
// image, and a little taller than the section measured at 100%, so the whole
// section is in the image. A section that outgrows its surface overflows and
// fails here. Measured: mushaf 1,433, controls 1,255 (on CI), audio 1,556, study and
// search 2,022, home and share 2,885.
const _sections = [
  (name: 'mushaf', gallery: MushafGallery(), height: 1450.0),
  (name: 'controls', gallery: ControlsGallery(), height: 1300.0),
  (name: 'audio', gallery: AudioGallery(), height: 1600.0),
  (name: 'study_search', gallery: StudySearchGallery(), height: 2050.0),
  (name: 'home_share', gallery: HomeShareGallery(), height: 2950.0),
];

void main() {
  for (final (:name, :gallery, :height) in _sections) {
    for (final theme in ReadingTheme.values) {
      testWidgets('the $name section in ${theme.name}', (tester) async {
        tester.view
          ..physicalSize = Size(400, height)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const root = ValueKey('golden-root');
        await tester.pumpWidget(
          goldenApp(
            theme,
            GalleryThemed(theme: theme, child: gallery),
            key: root,
          ),
        );
        await expectLater(
          find.byKey(root),
          matchesGoldenFile('goldens/gallery_${name}_${theme.name}.png'),
        );
      });
    }
  }
}
