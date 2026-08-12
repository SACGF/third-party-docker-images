#!/usr/bin/env bash
#
# Strip dead weight from a tree of conda environments before it is copied into
# the runtime image. Safe to run repeatedly (envs-full runs it after envs-core
# already has).
#
# Two things this script must not do, both learned the hard way:
#
#   * Never use -follow. Conda environments are dense with symlinks, so the same
#     physical directory is reachable by several paths: rm removes it via one
#     and find then errors on it via another. Worse, following a symlink out of
#     the tree would put rm -rf somewhere it has no business being.
#
#   * Never combine -prune with batched -exec rm -rf {} +. find is still walking
#     while rm deletes, so it queues a path, the parent disappears, and the stat
#     fails with "No such file or directory" -- which under set -e kills the
#     build. -depth processes contents before the containing directory and
#     avoids the race entirely.
#
# Note on hardlinks: conda hardlinks package files from the pkgs cache into each
# environment, so identical packages across the rule envs occupy disk once. The
# pkgs cache is a BuildKit cache mount and never enters a layer; dropping it
# only decrements link counts. This is why the tree must be moved downstream in
# a single COPY instruction.
set -euo pipefail

root="${1:?usage: prune-envs.sh <root>}"

conda clean --all --yes || true

# Plain files: no traversal race, no need for -depth.
find "$root" -type f \( -name '*.a' -o -name '*.pyc' -o -name '*.js.map' \
                        -o -name '*.debug' \) -delete

# Directories: -depth, no -prune, no -follow.
find "$root" -depth -type d -name '__pycache__' -exec rm -rf {} +

# Docs and man pages under share/. Kept narrow: several bioconda tools keep
# real, load-bearing data files elsewhere in share/, so only these four names
# are removed and only under a share/ directory.
find "$root" -depth -type d -path '*/share/*' \
     \( -name man -o -name doc -o -name gtk-doc -o -name info \) \
     -exec rm -rf {} +

# Apptainer runs as the invoking UID, which is neither root nor the image's.
chmod -R a+rX "$root"