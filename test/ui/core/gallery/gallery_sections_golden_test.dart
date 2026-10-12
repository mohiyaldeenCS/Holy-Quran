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
// fails here. Measured: mushaf 1,164, controls 554, audio 1,166, study and
// search 1,534, home and share 2,775.
const _sections = [
  (name: 'mushaf', gallery: MushafGallery(), height: 1200.0),
  (name: 'controls', gallery: ControlsGallery(), height: 600.0),
  (name: 'audio', gallery: AudioGallery(), height: 1200.0),
  (name: 'study_search', gallery: StudySearchGallery(), height: 1650.0),
  (name: 'home_share', gallery: HomeShareGallery(), height: 2850.0),
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
