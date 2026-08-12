#!/usr/bin/env bash
set -euo pipefail

# HOME is left at its image default (/home/caddsv), which is writable for the
# default UID. Under Apptainer neither of those holds: the invoking UID owns
# nothing in the image, and the host HOME is bind-mounted over it by default.
#
# If HOME is unusable, fall back to a private temporary directory -- NOT to /tmp
# itself, which Apptainer shares with the host and with every other job on the
# node.
if [[ -z "${HOME:-}" ]] || [[ ! -d "$HOME" ]] || [[ ! -w "$HOME" ]]; then
  HOME="$(mktemp -d -t caddsv-home-XXXXXXXX)"
  export HOME
  echo "note: image HOME was not writable; using ${HOME} for this run." >&2

  # Re-point anything that was derived from the build-time HOME.
  export XDG_CACHE_HOME="${HOME}/.cache"
  export CONDA_ENVS_DIRS="${HOME}/.conda/envs"
  export CONDA_PKGS_DIRS="${HOME}/.conda/pkgs"
  [[ -n "${HF_HOME:-}" ]] && export HF_HOME="${HOME}/.cache/huggingface"
fi

mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"

# Force the pre-baked env prefix. Snakemake names each rule env after a hash of
# the env spec *and* this path -- if a caller overrides it, every environment is
# rebuilt from scratch at run time, which is exactly what this image exists to
# avoid. Warn rather than fail, in case the override is deliberate.
readonly BAKED_PREFIX=/opt/caddsv/conda-envs
if [[ "${CADD_SV_CONDA_PREFIX:-$BAKED_PREFIX}" != "$BAKED_PREFIX" ]]; then
  echo "warning: CADD_SV_CONDA_PREFIX=${CADD_SV_CONDA_PREFIX} does not match the" >&2
  echo "         pre-baked prefix ${BAKED_PREFIX}; conda envs will be rebuilt." >&2
fi

# Friendlier failure than a Snakemake stack trace when the annotation volume was
# forgotten. Only a heuristic: it checks the default mount point, so an explicit
# --annotations-dir pointing elsewhere is left alone.
if [[ "${1:-}" == "run" ]] && [[ ! " $* " == *" --annotations-dir "* ]]; then
  if [[ ! -d /annotations ]] || [[ -z "$(ls -A /annotations 2>/dev/null)" ]]; then
    echo "error: no annotation bundle found at /annotations." >&2
    echo "       Mount it read-only, e.g.  -v /data/caddsv/annotations:/annotations:ro" >&2
    echo "       and pass --annotations-dir /annotations" >&2
    echo "       Fetch it once with: caddsv get annotations --annotations-dir <path>" >&2
    exit 2
  fi
fi

# Escape hatch for debugging: docker run <image> shell
if [[ "${1:-}" == "shell" ]]; then
  shift
  exec /bin/bash "$@"
fi

exec caddsv "$@"