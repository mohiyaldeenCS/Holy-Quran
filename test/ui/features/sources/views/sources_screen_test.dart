import 'dart:io';

import 'package:flutter/material.dart' hide IconButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:holyquran/data/repositories/sources_repository.dart';
import 'package:holyquran/domain/models/reading_theme.dart';
import 'package:holyquran/domain/models/source_credit.dart';
import 'package:holyquran/l10n/app_localizations.dart';
import 'package:holyquran/ui/core/theme/tokens.g.dart';
import 'package:holyquran/ui/core/widgets/button.dart';
import 'package:holyquran/ui/core/widgets/icon_button.dart';
import 'package:holyquran/ui/core/widgets/integrity_alert.dart';
import 'package:holyquran/ui/features/sources/view_models/sources_view_model.dart';
import 'package:holyquran/ui/features/sources/views/sources_screen.dart';

import '../../../../../testing/fakes/fake_licence_text_service.dart';
import '../../../../../testing/fakes/fake_link_service.dart';
import '../../../../../testing/fakes/fake_pack_install_repository.dart';
import '../../../../../testing/golden.dart';
import '../sources_fixtures.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

const _full = SourceCredit(
  name: 'Synthetic source name',
  url: 'https://example.invalid/synthetic/source',
  publisher: 'Synthetic publisher',
  version: '1',
  licenceText: 'Synthetic licence text',
  notice: 'Synthetic credit notice',
);
const _bare = SourceCredit(
  name: 'Synthetic bare source',
  url: 'https://example.invalid/synthetic/bare',
  publisher: null,
  version: null,
  licenceText: null,
  notice: null,
);

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  ReadingTheme theme = ReadingTheme.paper,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 640)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      theme,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: screen,
        ),
      ),
    ),
  );
}

Widget _list({
  List<SourceCredit> sources = const [_full, _bare],
  List<String> fontLicences = const ['Synthetic OFL one', 'Synthetic OFL two'],
  bool linkFailed = false,
  void Function(SourceCredit)? onOpen,
}) => SourcesList(
  sources: sources,
  fontLicences: fontLicences,
  linkFailed: linkFailed,
  onOpen: onOpen ?? (_) {},
);

void main() {
  testWidgets('shows a source name, link and texts as the pack gives them', (
    tester,
  ) async {
    await _pump(tester, _list());

    expect(find.text(_full.name), findsOneWidget);
    expect(find.text(_full.url), findsOneWidget);
    expect(find.text(_full.licenceText!), findsOneWidget);
    expect(find.text(_full.notice!), findsOneWidget);
  });

  testWidgets('hides the texts a source does not have', (tester) async {
    await _pump(tester, _list(sources: const [_bare], fontLicences: const []));

    expect(find.text(_bare.name), findsOneWidget);
    expect(find.text(_bare.url), findsOneWidget);
    expect(find.text('Synthetic licence text'), findsNothing);
    expect(find.byType(Text), findsNWidgets(2));
  });

  testWidgets('shows the publisher and version, and the font licences', (
    tester,
  ) async {
    await _pump(tester, _list());

    expect(
      find.text('Synthetic publisher${_l10n.dataSeparator}1'),
      findsOneWidget,
    );
    expect(find.text('Synthetic OFL one'), findsOneWidget);
    expect(find.text('Synthetic OFL two'), findsOneWidget);
  });

  testWidgets('lays each text out in the direction of its own words', (
    tester,
  ) async {
    const latin = 'Synthetic Latin notice.';
    const arabic = 'نص تجريبي';
    await _pump(
      tester,
      _list(
        sources: const [
          SourceCredit(
            name: 'Synthetic source',
            url: 'https://example.invalid/synthetic/dir',
            publisher: null,
            version: null,
            licenceText: arabic,
            notice: latin,
          ),
        ],
        fontLicences: const [],
      ),
    );

    TextDirection of(String text) =>
        Directionality.of(tester.element(find.text(text)));
    expect(of(latin), TextDirection.ltr);
    expect(of(arabic), TextDirection.rtl);
  });

  testWidgets('announces a failed link and marks names as headings', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _list(linkFailed: true));

    expect(
      tester.getSemantics(
        find
            .ancestor(
              of: find.byType(IntegrityAlert),
              matching: find.byType(Semantics),
            )
            .first,
      ),
      isSemantics(isLiveRegion: true),
    );
    expect(
      tester.getSemantics(find.text(_full.name)),
      isSemantics(isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('opens the link of the source tapped', (tester) async {
    final opened = <SourceCredit>[];
    await _pump(tester, _list(onOpen: opened.add));

    await tester.tap(find.text(_bare.url));

    expect(opened, [_bare]);
  });

  testWidgets('every link is a button at least 48 high, read left to right', (
    tester,
  ) async {
    await _pump(tester, _list());

    for (final button in tester.widgetList<Button>(find.byType(Button))) {
      expect(
        tester.getSize(find.byWidget(button)).height,
        greaterThanOrEqualTo(AppSizes.targetMin),
      );
    }
    final directionality = tester.widget<Directionality>(
      find
          .ancestor(
            of: find.byType(Button).first,
            matching: find.byType(Directionality),
          )
          .first,
    );
    expect(directionality.textDirection, TextDirection.ltr);
  });

  testWidgets('says that a link could not be opened', (tester) async {
    await _pump(tester, _list(linkFailed: true));

    expect(find.byType(IntegrityAlert), findsOneWidget);
    expect(find.text(_l10n.connectionFailed), findsOneWidget);
  });

  testWidgets('shows the title and a labelled back button', (tester) async {
    await _pump(tester, const SourcesScreen(viewModel: null));

    expect(find.text(_l10n.sourcesTitle), findsOneWidget);
    expect(find.bySemanticsLabel(_l10n.back), findsOneWidget);
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byType(SourcesList), findsNothing);
  });

  testWidgets('lists the sources of the installed packs', (tester) async {
    final root = Directory.systemTemp.createTempSync('sources_screen');
    addTearDown(() => root.deleteSync(recursive: true));
    final pack = (await tester.runAsync(() => installedWithSource(root)))!;
    final links = FakeLinkService();
    final viewModel = SourcesViewModel(
      repository: PackSourcesRepository(
        installs: FakePackInstallRepository(installed: [pack]),
        links: links,
        licences: FakeLicenceTextService(['Synthetic OFL text']),
      ),
    );
    addTearDown(viewModel.dispose);

    await _pump(tester, SourcesScreen(viewModel: viewModel));
    await tester.tap(find.text('https://example.invalid/synthetic/source'));
    await tester.pump();

    expect(find.text('Synthetic source name'), findsOneWidget);
    expect(find.text('Synthetic OFL text'), findsOneWidget);
    expect(links.opened, [
      Uri.parse('https://example.invalid/synthetic/source'),
    ]);
  });

  for (final theme in ReadingTheme.values) {
    testWidgets('lays out at 200% text in ${theme.name}', (tester) async {
      await _pump(
        tester,
        const SourcesScreen(viewModel: null),
        theme: theme,
        textScale: 2,
      );
      expect(tester.takeException(), isNull);

      await _pump(tester, _list(), theme: theme, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the list of sources and the link alert', tags: ['golden'], (
    tester,
  ) async {
    await expectGoldensInThemes(
      tester,
      'sources_list',
      (context) =>
          SizedBox(width: 360, height: 560, child: _list(linkFailed: true)),
      surfaceSize: const Size(400, 600),
    );
  });
}
