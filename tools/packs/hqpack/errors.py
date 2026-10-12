"""The one error the pipeline raises, and how it names a code point.

A message names addresses, numbers, field names, byte offsets and code points
as U+XXXX only, never a source value, so that no Quran text reaches a log.
"""


class PackError(Exception):
    """A source or a pack breaks a rule; the build stops and writes nothing."""


def code_point(c):
    """`U+XXXX` for a code point or a one-character string."""
    if isinstance(c, str):
        c = ord(c)
    return "U+%04X" % c
