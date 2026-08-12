#!/usr/bin/env bash
#
# Strip dead weight from a tree of conda environments before it is copied into
# the runtime image. Safe to run repeatedly (envs-full runs it after envs-core
# already has).
#
# Note on hardlinks: conda hardlinks package files from the pkgs cache into
# each environment, so identical packages across the ~dozen rule envs occupy
# disk once. The pkgs cache here is a BuildKit cache mount and never enters a
# layer, and dropping it does not duplicate anything -- it only decrements link
# counts. This is why `conda clean` is cheap and why the tree must be moved in
# a single COPY instruction downstream.
set -euo pipefail

root="${1:?usage: prune-envs.sh <root>}"

conda clean --all --yes || true

# Static archives and build-time artefacts: never needed to run anything.
find "$root" -follow -type f -name '*.a' -delete
find "$root" -follow -type f -name '*.pyc' -delete
find "$root" -follow -type f -name '*.js.map' -delete
find "$root" -follow -type d -name '__pycache__' -prune -exec rm -rf {} +
find "$root" -follow -type d -name 'tests' -prune -exec rm -rf {} +

# Docs and locale data. Keep man pages out but leave share/ itself alone --
# several bioconda tools keep real data files there.
find "$root" -follow -type d \
     \( -name man -o -name doc -o -name gtk-doc -o -name info \) \
     -path '*/share/*' -prune -exec rm -rf {} +

# Debug symbols, if any survived.
find "$root" -follow -type f -name '*.debug' -delete

# Apptainer runs as the invoking UID, which will not be root or 1000.
chmod -R a+rX "$root"