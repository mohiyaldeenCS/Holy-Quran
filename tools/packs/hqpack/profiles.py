"""What a text pack of each riwaya must hold, checked against the source at build time.

The totals are fixed here, never taken from the build description, so that a
description cannot relax them (PRD 9.4: 114 surahs; docs/SOURCES.md row 1:
6,236 ayat; docs/CONTENT_PACKS.md: 240 quarters, a hizb every fourth, 604
pages of the 1421H edition; P4: no separate basmala for surahs 1 and 9).
"""

from __future__ import annotations

from dataclasses import dataclass

from .errors import PackError
from .options import PAUSE_MARKS

DIVISION_KINDS = ("juz", "hizb", "rub", "page")

RUB_EL_HIZB = 0x06DE
SAJDA_SIGN = 0x06E9


@dataclass(frozen=True)
class Profile:
    surahs: int
    ayat: int
    divisions: dict
    without_basmala: frozenset
    # D-079, whatever the download URL says: code points the text must not
    # hold, and groups of which it must hold at least one code point each.
    forbidden_code_points: frozenset
    required_code_points: tuple
    # PRD 9.4 compares a Hafs text with the KFGQPC text character by character,
    # and P2 compares the page list with the KFGQPC file; until B0.2 adds that
    # step, a profile that needs it cannot be built.
    needs_kfgqpc_comparison: bool


PROFILES = {
    "hafs": Profile(
        surahs=114,
        ayat=6236,
        divisions={"juz": 30, "hizb": 60, "rub": 240, "page": 604},
        without_basmala=frozenset({1, 9}),
        forbidden_code_points=frozenset({RUB_EL_HIZB}),
        required_code_points=(frozenset(PAUSE_MARKS), frozenset({SAJDA_SIGN})),
        needs_kfgqpc_comparison=True,
    ),
    # The shape of synthetic_source.py, so that every build check runs in CI
    # without any Quran text.
    "synthetic": Profile(
        surahs=3,
        ayat=8,
        divisions={"juz": 2, "hizb": 2, "rub": 8, "page": 4},
        without_basmala=frozenset({2}),
        forbidden_code_points=frozenset({RUB_EL_HIZB}),
        required_code_points=(frozenset(PAUSE_MARKS), frozenset({SAJDA_SIGN})),
        needs_kfgqpc_comparison=False,
    ),
}

SYNTHETIC_ID_PREFIX = "synthetic-"


def profile_for(riwaya, pack_id):
    """The profile of `riwaya`; a synthetic pack and only a synthetic pack has a synthetic id."""
    profile = PROFILES.get(riwaya)
    if profile is None:
        raise PackError(
            "riwaya %s has no profile in profiles.py; its totals must be added "
            "and reviewed before a pack is built" % riwaya
        )
    if (riwaya == "synthetic") != pack_id.startswith(SYNTHETIC_ID_PREFIX):
        raise PackError(
            "id %s and riwaya %s: a pack id begins with %r exactly when its "
            "riwaya is synthetic" % (pack_id, riwaya, SYNTHETIC_ID_PREFIX)
        )
    return profile
