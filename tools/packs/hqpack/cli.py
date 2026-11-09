"""The command line: build, verify, sign, verify-signature, compare, review-page, kfgqpc-counts and drift.

Output is paths, counts, hashes and `U+XXXX` only, never a text value. Exit
codes: 0 done, 64 usage, 65 a source or a pack breaks a rule, 70 anything
else (printed by its type alone, since its message might hold text).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from . import compare, drift, review_page
from .build import build_pack
from .digest import sha256_bytes
from .errors import PackError
from .font import read_font
from .kfgqpc_counts import encode_counts, kfgqpc_counts
from .mark_table import read_mark_table
from .profiles import PROFILES
from .tanzil_metadata import read_tanzil_metadata
from .tanzil_text import read_tanzil_text
from .signing import SIGNATURE_FILE, OpenSslEd25519Signer, sign_pack, verify_signature
from .verify import verify_pack

EX_USAGE = 64
EX_DATAERR = 65
EX_SOFTWARE = 70

UNSIGNED = (
    "signature: none, the pack is unsigned (%s absent; signing key custody is "
    "undecided, D-024, O-03)" % SIGNATURE_FILE
)
TEST_COPY = (
    "unapproved test copy: the KFGQPC comparison was not run; never upload or bundle this "
    "pack, and keep it out of every Git working tree (D-165)"
)


class _Usage(Exception):
    pass


class _Parser(argparse.ArgumentParser):
    def error(self, message):
        raise _Usage("%s\n%s" % (self.format_usage().rstrip(), message))


def main(argv=None, out=None, err=None):
    out = out or sys.stdout
    err = err or sys.stderr
    try:
        args = _parser().parse_args(argv)
        return args.run(args, out)
    except _Usage as e:
        print(e, file=err)
        return EX_USAGE
    except PackError as e:
        print("refused: %s" % e, file=err)
        return EX_DATAERR
    except Exception as e:  # noqa: BLE001 - the message may hold source text
        print("failed: %s" % type(e).__name__, file=err)
        return EX_SOFTWARE


def _parser():
    parser = _Parser(prog="pack.py", description="Build, verify and sign content packs (docs/CONTENT_PACKS.md).")
    commands = parser.add_subparsers(dest="command", parser_class=_Parser)
    commands.required = True

    build = commands.add_parser("build", help="build an unsigned pack from a build description")
    build.add_argument("--config", required=True, type=Path, help="the build description (JSON)")
    build.add_argument("--font", required=True, type=Path, help="the font the text is drawn with")
    build.add_argument("--out", required=True, type=Path, help="where <id>/<version>/ is written")
    build.add_argument(
        "--unapproved-test-copy",
        action="store_true",
        help="build a hafs pack without the KFGQPC comparison, as an unapproved test copy "
        "for the owner's own phone (D-165): the id begins with unapproved-, reviews are "
        "empty and the output is outside every Git working tree",
    )
    build.add_argument("--kfgqpc", type=Path, help="KFGQPC's hafsData_v2-0.json; required for a hafs pack (PRD 9.4)")
    build.add_argument("--table", type=Path, help="the table of known differences; required with --kfgqpc")
    build.set_defaults(run=_build)

    verify = commands.add_parser("verify", help="verify a pack directory <id>/<version>")
    _pack_inputs(verify)
    verify.set_defaults(run=_verify)

    sign = commands.add_parser("sign", help="verify a pack with its font and mark table, then write manifest.json.sig")
    _pack_inputs(sign, required=True)
    sign.add_argument("--key", required=True, type=Path, help="Ed25519 private key (PEM) of the key holder")
    sign.add_argument("--openssl", default="openssl", help="the OpenSSL 3 executable")
    sign.set_defaults(run=_sign)

    check = commands.add_parser("verify-signature", help="check manifest.json.sig with a public key")
    check.add_argument("pack", type=Path)
    check.add_argument("--public-key", required=True, type=Path, help="Ed25519 public key (PEM)")
    check.add_argument("--openssl", default="openssl", help="the OpenSSL 3 executable")
    check.set_defaults(run=_verify_signature)

    comparison = commands.add_parser(
        "compare", help="compare the Tanzil text and metadata with the KFGQPC Hafs file (PRD 9.4, P2)"
    )
    comparison.add_argument("--text", required=True, type=Path, help="the Tanzil text XML")
    comparison.add_argument("--metadata", required=True, type=Path, help="Tanzil's quran-data.xml")
    comparison.add_argument("--kfgqpc", required=True, type=Path, help="KFGQPC's hafsData_v2-0.json")
    comparison.add_argument("--table", required=True, type=Path, help="the table of known differences")
    comparison.add_argument("--report", required=True, type=Path, help="where the report (JSON, code points only) is written")
    comparison.set_defaults(run=_compare)

    review = commands.add_parser(
        "review-page",
        help="run the KFGQPC comparison and write the reciter's review page (D-176, D-178) into an "
        "empty folder outside every Git working tree",
    )
    review.add_argument("--text", required=True, type=Path, help="the Tanzil text XML")
    review.add_argument("--metadata", required=True, type=Path, help="Tanzil's quran-data.xml")
    review.add_argument("--kfgqpc", required=True, type=Path, help="KFGQPC's hafsData_v2-0.json")
    review.add_argument("--table", required=True, type=Path, help="the table of known differences")
    review.add_argument("--tanzil-font", required=True, type=Path, help="Amiri Quran, the font of the Tanzil text")
    review.add_argument("--kfgqpc-font", required=True, type=Path, help="KFGQPC's uthmanic_hafs_v20.ttf")
    review.add_argument("--out", required=True, type=Path, help="a new or empty folder outside every Git working tree")
    review.set_defaults(run=_review_page)

    counts = commands.add_parser(
        "kfgqpc-counts", help="write the ayah counts per surah of the KFGQPC Hafs file (docs/CONTENT_PACKS.md P5)"
    )
    counts.add_argument("--kfgqpc", required=True, type=Path, help="KFGQPC's hafsData_v2-0.json")
    counts.add_argument("--date", required=True, help="the day the counts are taken, YYYY-MM-DD")
    counts.add_argument("--out", required=True, type=Path, help="where the counts file is written")
    counts.set_defaults(run=_kfgqpc_counts)

    timing = commands.add_parser(
        "drift",
        help="measure drift between quran-align word timing and an everyayah folder of SSSAAA.mp3 files "
        "(B0.5, D-167 (2), D-179)",
    )
    timing.add_argument("--timing", required=True, type=Path, help="the quran-align JSON of the edition")
    timing.add_argument(
        "--audio", required=True, type=Path, help="the folder of SSSAAA.mp3 files, named as the edition"
    )
    timing.add_argument("--edition", required=True, help="the everyayah folder name the timing file is for")
    timing.add_argument("--text", type=Path, help="the Tanzil quran-uthmani text XML, with --metadata")
    timing.add_argument("--metadata", type=Path, help="Tanzil's quran-data.xml, with --text")
    timing.add_argument(
        "--report", type=Path, help="where the report (JSON, numbers only) is written, outside every Git working tree"
    )
    timing.set_defaults(run=_drift)
    return parser


def _pack_inputs(parser, required=False):
    parser.add_argument("pack", type=Path, help="the pack directory <id>/<version>")
    parser.add_argument("--font", type=Path, required=required, help="check the font's hash, name, version and coverage")
    parser.add_argument("--mark-table", type=Path, required=required, help="check every mark against the mark table")


def _build(args, out):
    result = build_pack(
        args.config,
        args.font,
        args.out,
        unapproved=args.unapproved_test_copy,
        kfgqpc=args.kfgqpc,
        table=args.table,
    )
    counts = result.counts
    print("pack %s" % result.directory, file=out)
    print("sqlite %s" % result.sqlite_version, file=out)
    print(_counts_line(counts), file=out)
    print(
        "divisions %s"
        % " ".join("%s %d" % item for item in counts["divisions"].items()),
        file=out,
    )
    print("text.sqlite sha256 %s" % result.text_sha256, file=out)
    print("manifest.json sha256 %s" % result.manifest_sha256, file=out)
    for surah, value in result.surah_sha256.items():
        print("surah %s sha256 %s" % (surah, value), file=out)
    print("verified", file=out)
    if args.unapproved_test_copy:
        print(TEST_COPY, file=out)
    print(UNSIGNED, file=out)
    return 0


def _verify(args, out):
    report = _report(args)
    for problem in report.problems:
        print("problem: %s" % problem, file=out)
    if report.counts is not None:
        print(_counts_line(report.counts), file=out)
    print(_signature_line(report.signed), file=out)
    if report.problems:
        print("%d problems" % len(report.problems), file=out)
        return EX_DATAERR
    print("verified", file=out)
    return 0


def _sign(args, out):
    report = _report(args)
    if report.problems:
        for problem in report.problems:
            print("problem: %s" % problem, file=out)
        raise PackError("the pack does not verify; it is not signed")
    path = sign_pack(args.pack, OpenSslEd25519Signer(args.key, openssl=args.openssl))
    print("signed %s" % path, file=out)
    return 0


def _verify_signature(args, out):
    if verify_signature(args.pack, args.public_key, openssl=args.openssl):
        print("signature valid", file=out)
        return 0
    print("signature INVALID", file=out)
    return EX_DATAERR


def _compare(args, out):
    text_bytes = args.text.read_bytes()
    metadata_bytes = args.metadata.read_bytes()
    tanzil_sha256 = {"text": sha256_bytes(text_bytes), "metadata": sha256_bytes(metadata_bytes)}
    report = compare.run_comparison(
        read_tanzil_text(text_bytes),
        read_tanzil_metadata(metadata_bytes),
        args.kfgqpc,
        args.table,
        PROFILES["hafs"],
        tanzil_sha256,
    )
    args.report.write_bytes(compare.encode_report(report))
    print("report %s" % args.report, file=out)
    print("tanzil text sha256 %s" % tanzil_sha256["text"], file=out)
    print("tanzil metadata sha256 %s" % tanzil_sha256["metadata"], file=out)
    print("kfgqpc sha256 %s" % report["kfgqpc"]["sha256"], file=out)
    print("table version %d sha256 %s" % (report["table"]["version"], report["table"]["sha256"]), file=out)
    print(compare.summary(report), file=out)
    if not report["passed"]:
        print("problems found: the comparison fails", file=out)
        return EX_DATAERR
    print("no undocumented difference", file=out)
    return 0


def _review_page(args, out):
    result = review_page.write_review_page(
        args.text,
        args.metadata,
        args.kfgqpc,
        args.table,
        args.tanzil_font,
        args.kfgqpc_font,
        args.out,
        PROFILES["hafs"],
    )
    sections = result.sections
    print("page %s" % (result.directory / review_page.PAGE_FILE), file=out)
    for key, value in result.inputs.items():
        print("%s %s" % (key.replace("_", " "), value), file=out)
    print(compare.summary(result.report), file=out)
    print(
        "section A places %d, section B patterns %d (places %d), section C patterns %d (places %d), "
        "section D rows %d (surah-opening quarter starts %d)"
        % (
            len(sections.a),
            len(sections.b),
            sum(len(card.places) for card in sections.b),
            len(sections.c),
            sum(len(card.places) for card in sections.c),
            len(result.report["page_differences"])
            + len(result.report["juz_differences"])
            + len(result.report["quarter_differences"])
            + len(result.surah_opening_quarters),
            len(result.surah_opening_quarters),
        ),
        file=out,
    )
    print(
        "the folder holds Quran text: keep it and the reviewer's decisions file on this machine, "
        "outside every Git working tree; never commit or upload them",
        file=out,
    )
    return 0


def _kfgqpc_counts(args, out):
    counts = kfgqpc_counts(args.kfgqpc, args.date, PROFILES["hafs"])
    args.out.write_bytes(encode_counts(counts))
    print("counts %s" % args.out, file=out)
    print("kfgqpc sha256 %s" % counts["kfgqpc_file"]["sha256"], file=out)
    print("surahs %d ayat %d" % (len(counts["surahs"]), counts["total"]), file=out)
    return 0


def _drift(args, out):
    if (args.text is None) != (args.metadata is None):
        raise _Usage("--text and --metadata go together")
    if args.report is not None:
        drift.check_report_path(args.report)
    report = drift.run_drift(
        args.timing, args.audio, args.edition, PROFILES["hafs"], text_path=args.text, metadata_path=args.metadata
    )
    data = drift.encode_report(report)
    if args.report is not None:
        args.report.write_bytes(data)
    for line in drift.lines(report):
        print(line, file=out)
    if args.report is not None:
        print("report %s" % args.report, file=out)
    problems = report["words"]["word_index_problems"]
    if report["summary"]["verdict"] != "PASS" or problems:
        return EX_DATAERR
    return 0


def _report(args):
    font = read_font(args.font.read_bytes()) if args.font else None
    marks = read_mark_table(args.mark_table.read_bytes()) if args.mark_table else None
    return verify_pack(args.pack, mark_code_points=marks, font=font)


def _counts_line(counts):
    return "counts surahs %d ayat %d words %d marks %d sajdas %d" % (
        counts["surahs"],
        counts["ayat"],
        counts["words"],
        counts["marks"],
        counts["sajdas"],
    )


def _signature_line(signed):
    if signed:
        return "signature: %s present, not checked here (use verify-signature)" % SIGNATURE_FILE
    return UNSIGNED
