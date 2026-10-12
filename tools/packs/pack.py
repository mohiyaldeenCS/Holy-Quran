#!/usr/bin/env python3
"""Runs the content pack pipeline: python3 tools/packs/pack.py --help (see README.md)."""

import sys

from hqpack.cli import main

if __name__ == "__main__":
    sys.exit(main())
