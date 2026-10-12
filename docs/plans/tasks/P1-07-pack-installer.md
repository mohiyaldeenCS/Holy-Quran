# P1-07 — Download queue and pack installer (M1.4)

Wave 1 · Agent `data-builder` · Key 1 · Cap $30 · Base `main` · Needs: P1-02, P1-03.

## Why

- `OF-04`: «قائمة تنزيل تتابعية تُستأنف، بخيار Wi-Fi فقط، وتتوقف مع تنبيه عند ضيق المساحة».
- `OF-05`: «كل ملف يُتحقق ببصمته وبتوقيع بيان حزمته قبل تفعيله».
- `OF-06`: «تحديث ذرّي، وإمكان الرجوع للإصدار السابق». `OF-07`: «حذف حزمة لا يمس بيانات
  المستخدم المرتبطة بها». `NF-15`: TLS 1.2 or later.
- Criteria: «قطع الشبكة أثناء التنزيل ثم إعادتها يكمل من حيث توقف. ملف تالف عمدًا يُرفض
  ويُعاد تنزيله.» and «التنزيل يُستأنف دون إعادة ما اكتمل، وكل ملف يُتحقق ببصمته قبل اعتماده».

Read D-107 and D-108 in `docs/plans/PHASE1.md` §6 and `docs/spikes/S5-downloads.md`
("Findings for M1.4").

## Plan first

Ask `flutter-architect` for the plan. Port spike S5: its code is at the commit the S5
page cites (`git show <sha>:spike/s5/…`; if the commit is missing, work from the page).

## Do

1. `lib/data/services/download_service.dart`: `background_downloader` behind an
   interface (enqueue, pause, resume, cancel, progress, Wi-Fi only), its base
   directories rather than absolute paths (iOS moves them).
2. `lib/data/services/connectivity_service.dart` (`connectivity_plus`): the "waiting
   for Wi-Fi" signal the downloader lacks.
3. `lib/data/services/free_space_service.dart`: free space by the means the lead
   chose in step 0 (`docs/DECISIONS.md`); if none was chosen, the interface only, and
   say so.
4. `lib/data/services/installed_packs_store.dart` (named outside `pack_*.dart`, the
   pack-write guard): `<application support>/packs/<id>/<version>/`, one
   `active.json` per pack id replaced by rename, the previous version kept.
5. `PackInstallRepository` (abstract and implementation): a sequential queue of jobs;
   each downloads the files, checks every SHA-256 (a bad file is deleted and fetched
   again once), verifies the manifest through `PackRepository.verify`, applies the
   signature policy (refuse `invalid`; accept `notChecked` only when not
   `kReleaseMode`, D-108; packs are signed in CI by the task `sign-pack`, O-03, and a
   signature by the key in use or the spare is `valid`), activates atomically, and supports rollback and delete.
   Low space stops the queue with a state the UI can show. Only `https` URLs are
   accepted; the policy is injected so tests can use a local server. Test packs are
   assets of this repository's GitHub Releases (O-08, D-109), whose download URLs
   redirect to GitHub's storage host: follow `https` redirects, refuse a redirect to
   any other scheme.
6. Fill `lib/config/providers/pack_install_providers.dart`; fake
   `testing/fakes/fake_pack_install_repository.dart`.

## Tests

With a local `HttpServer` serving synthetic packs from `testing/packs/` and a fake
downloader: resume after a dropped connection without re-fetching finished bytes;
corrupt file rejected and re-fetched; bad manifest hash refused; `invalid` signature
refused; a pack signed with the spare key accepted; an `https` redirect followed and
a redirect to `http` refused; rollback restores the previous version; delete leaves other packs and any
other folder untouched; an `http` URL refused. Device checks (Wi-Fi gating, real low
space) are pending human checks.

## Acceptance

- `dart format .` changes nothing, `flutter analyze` reports no issues, and
  `flutter test --exclude-tags golden test tools/gen/test` passes (add `spike` if that
  folder exists). Run all three before the last commit, fix what fails, and run them
  again. Never weaken, skip or delete a test to make it pass.
- Golden images are made only by the CI `goldens` task (D-056). Write new golden tests
  tagged `golden`; never create or commit a `.png` file. A new golden test without its
  image is expected.
- Each acceptance criterion quoted above is reported as met (with its test), partial
  (with the reason) or a pending human check (device, reviewer or owner).

## Self-review

Through the Task tool, run `code-reviewer` on your whole diff. Fix every blocking
and should-fix finding, re-run the checks, and ask again until none remains. Say in
the report which nits you left and why.

## Files

### You own
- `lib/data/services/download_service.dart`
- `lib/data/services/connectivity_service.dart`
- `lib/data/services/free_space_service.dart`
- `lib/data/services/installed_packs_store.dart`
- `lib/data/repositories/pack_install_repository.dart`
- `lib/domain/models/install_job.dart`
- `lib/domain/models/installed_pack.dart`
- `lib/domain/models/download_progress.dart`
- `lib/config/providers/pack_install_providers.dart`
- `testing/fakes/fake_pack_install_repository.dart`
- The tests that mirror these files (same path under test/, ending in _test.dart)

### Do not touch
`lib/data/repositories/local_pack_repository.dart`, `lib/data/services/pack_database.dart`,
`lib/data/services/manifest_signature.dart`, the manifest files, `testing/packs/`,
`android/`, `pubspec.*`.

## Rules

- `CLAUDE.md` and `docs/WORKFLOW.md` apply in full. Quran text comes only from packs,
  by address, through `QuranText`, `SurahName` or a sink listed under
  `test/guards/allow/`; it is never typed, pasted, trimmed, normalised or split by the
  app. Tests use the synthetic packs of `testing/packs/` and obviously synthetic text.
- No generated content. The identity is closed. No Arabic wording of your own: use
  only keys in `lib/l10n/app_ar.arb`; if one you need is missing, leave that element
  out and list it in the report.
- Edit only the files under "You own"; every file listed there is handed over to you
  for this task, whatever your agent file says. If another file must change, stop that
  part and report it. A gallery title or sample label reuses an existing key. Never edit `docs/PROJECT_STATUS.md`, `docs/DECISIONS.md`, `.github/`, or
  `pubspec.*`.
- Few comments, saying why; small files; no dead code or speculative options; no
  literal colours, font names or inline design numbers in feature code.
- Never print, write or commit secrets or environment variables; do not run `env`,
  `printenv` or `set`.
- Commit on the current branch only. Do not push, open pull requests, change remotes or
  call the GitHub API.

## Commits

- `feat(resources): queue resumable pack downloads with Wi-Fi only (OF-04)`
- `feat(resources): verify, activate and roll back packs (OF-06)`

## Report

In English: what was done; files changed; the checks you ran with their exact results;
each acceptance criterion as met, partial or pending human check; what is unfinished
and why; strings and icons that were missing; what `docs/PROJECT_STATUS.md` and
`docs/DECISIONS.md` should record; questions for the owner in Arabic, recommended
option first, marked «(موصى به)».

Wait for every background task before writing the report, and make your last message the whole report, never a pointer to an earlier message: only the last message reaches the pull request.
