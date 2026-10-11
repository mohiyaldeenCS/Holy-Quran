"""The command line: build, verify, sign and verify-signature.

Output is paths, counts, hashes and `U+XXXX` only, never a text value. Exit
codes: 0 done, 64 usage, 65 a source or a pack breaks a rule, 70 anything
else (printed by its type alone, since its message might hold text).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .build import build_pack
from .errors import PackError
from .font import read_font
from .mark_table import read_mark_table
from .signing import SIGNATURE_FILE, OpenSslEd25519Signer, sign_pack, verify_signature
from .verify import verify_pack

EX_USAGE = 64
EX_DATAERR = 65
EX_SOFTWARE = 70

UNSIGNED = (
    "signature: none, the pack is unsigned (%s absent; signing key custody is "
    "undecided, D-024, O-03)" % SIGNATURE_FILE
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
    return parser


def _pack_inputs(parser, required=False):
    parser.add_argument("pack", type=Path, help="the pack directory <id>/<version>")
    parser.add_argument("--font", type=Path, required=required, help="check the font's hash, name, version and coverage")
    parser.add_argument("--mark-table", type=Path, required=required, help="check every mark against the mark table")


def _build(args, out):
    result = build_pack(args.config, args.font, args.out)
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
