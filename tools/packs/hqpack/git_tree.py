"""Whether a path lies inside a Git working tree, without needing a `git` program."""

from __future__ import annotations

import os
from pathlib import Path


def git_tree(path):
    """The nearest directory above `path` that holds `.git` (a folder, or a file in a worktree or submodule), else None."""
    here = Path(os.path.realpath(str(path)))
    for directory in (here, *here.parents):
        if os.path.lexists(str(directory / ".git")):
            return directory
    return None
