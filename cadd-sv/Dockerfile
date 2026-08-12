# syntax=docker/dockerfile:1.7
#
# Slimline CADD-SV container.
#
#   * software only -- the annotation bundle (tens of GB) is mounted, never baked
#   * Snakemake's per-rule conda envs are pre-created at build time via
#     `caddsv get envs`, so a run never solves or downloads an environment
#   * the build is hermetic: no annotations, no model weights, no example data
#
# Build the default (coordinate-based scoring) image:
#   DOCKER_BUILDKIT=1 docker build -t caddsv:2.0 .
#
# Build the SegmentNT-capable image (--seqresolved / --seqonly, several GB more):
#   DOCKER_BUILDKIT=1 docker build --target segmentnt -t caddsv:2.0-segmentnt .
#
# bioconda is linux-64 only, so pin the platform on arm64 hosts.

ARG CADDSV_VERSION=2.0.2
ARG PYTHON_VERSION=3.12

###############################################################################
# Stage 1 -- base: the runtime environment (CLI + Snakemake + conda)
###############################################################################
FROM --platform=linux/amd64 mambaorg/micromamba:2.0.5-debian12-slim AS base

ARG CADDSV_VERSION
ARG PYTHON_VERSION

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Everything we ship lives under one root so a single COPY --from can move it
# and preserve the hardlinks conda creates between environments.
ENV CADDSV_ROOT=/opt/caddsv \
    CADDSV_ENV=/opt/caddsv/env \
    CADDSV_CONDA_ENVS=/opt/caddsv/conda-envs \
    MAMBA_ROOT_PREFIX=/opt/micromamba \
    CONDA_PKGS_DIRS=/opt/pkgs

# `conda` is deliberately included alongside caddsv: even when every rule env
# already exists, Snakemake shells out to the conda frontend to activate them.
# micromamba is not a drop-in substitute, and is used here only as the solver.
RUN --mount=type=cache,target=/opt/pkgs,sharing=locked \
    micromamba create -y -p "${CADDSV_ENV}" \
      -c conda-forge -c bioconda \
      --channel-priority strict \
      "python=${PYTHON_VERSION}" \
      "caddsv=${CADDSV_VERSION}" \
      conda

ENV PATH=/opt/caddsv/env/bin:$PATH

COPY prune-envs.sh /usr/local/bin/prune-envs.sh
RUN chmod +x /usr/local/bin/prune-envs.sh

###############################################################################
# Stage 2 -- envs-core: coordinate-based rule environments
#
# CRITICAL: --conda-prefix must be byte-identical here and at run time.
# Snakemake names each environment directory after a hash of the env spec AND
# the prefix path. A different prefix at run time is not an error -- it is a
# silent, full rebuild of everything this stage just did.
###############################################################################
FROM base AS envs-core

RUN --mount=type=cache,target=/opt/pkgs,sharing=locked \
    set -eux; \
    caddsv get envs \
      --use-conda \
      --conda-prefix "${CADDSV_CONDA_ENVS}" \
      --coordinate-based-only; \
    test -n "$(ls -A "${CADDSV_CONDA_ENVS}" 2>/dev/null)"; \
    prune-envs.sh "${CADDSV_ROOT}"

###############################################################################
# Stage 3 -- envs-full: adds the SegmentNT rule environments (torch etc.)
#
# Built on top of envs-core rather than from scratch, so the coordinate-based
# environments are reused and only the missing ones are created.
###############################################################################
FROM envs-core AS envs-full

RUN --mount=type=cache,target=/opt/pkgs,sharing=locked \
    set -eux; \
    caddsv get envs \
      --use-conda \
      --conda-prefix "${CADDSV_CONDA_ENVS}"; \
    prune-envs.sh "${CADDSV_ROOT}"

###############################################################################
# Stage 4 -- runtime-common: everything except the environments themselves
#
# Designed for Nextflow, which runs the container as
#   docker run ... -w <taskdir> <image> /bin/bash -ue .command.sh
# Consequences, all deliberate:
#   * NO ENTRYPOINT. Since Nextflow 22.08 the image ENTRYPOINT is respected,
#     so any ENTRYPOINT here would receive "/bin/bash -ue .command.sh" as its
#     arguments and break every task.
#   * NO USER. Nextflow bind-mounts the task directory from the host and the
#     task must write .command.out there; a baked-in UID that does not match
#     the host user fails on permissions. Add -u via docker.runOptions if you
#     want to drop privileges.
#   * Nothing is derived from $HOME, which may be unset or non-existent when
#     Nextflow passes -u.
#   * Tools are reachable on the default PATH with no activation step.
###############################################################################
FROM --platform=linux/amd64 debian:12-slim AS runtime-common

LABEL org.opencontainers.image.title="cadd-sv" \
      org.opencontainers.image.source="https://github.com/kircherlab/CADD-SV" \
      org.opencontainers.image.licenses="MIT"

# bash: Snakemake wraps every rule's shell block in it, and Nextflow invokes
#   /bin/bash -ue explicitly.
# procps: Nextflow's task wrapper shells out to ps for resource tracing, and
#   caddsv --check-time needs it too. Tasks fail without it.
# coreutils/grep/sed/gawk: relied on by both wrappers; present in the base but
#   named here so nobody "slims" them away later.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bash procps coreutils grep sed gawk ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Writable, HOME-independent locations for anything conda may want to record.
# Sticky world-writable so that any UID Nextflow runs as can use them.
RUN mkdir -p /var/cache/caddsv/conda /var/cache/caddsv/xdg /annotations /data \
 && chmod -R 1777 /var/cache/caddsv \
 && chmod 0755 /annotations /data

ENV PATH=/opt/caddsv/env/bin:$PATH \
    CADD_SV_CONDA_PREFIX=/opt/caddsv/conda-envs \
    SNAKEMAKE_CONDA_PREFIX=/opt/caddsv/conda-envs \
    CONDA_ENVS_DIRS=/var/cache/caddsv/conda/envs \
    CONDA_PKGS_DIRS=/var/cache/caddsv/conda/pkgs \
    XDG_CACHE_HOME=/var/cache/caddsv/xdg \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1

# Belt-and-braces for PATH. Apptainer and some executors rebuild PATH from
# their own defaults rather than the image config, which would leave caddsv
# unreachable. /usr/local/bin survives that.
RUN ln -sf /opt/caddsv/env/bin/caddsv /usr/local/bin/caddsv \
 && ln -sf /opt/caddsv/env/bin/snakemake /usr/local/bin/snakemake \
 && ln -sf /opt/caddsv/env/bin/conda /usr/local/bin/conda

# Overridden by Nextflow (-w <taskdir>); only affects a bare docker run.
WORKDIR /data

# No ENTRYPOINT -- see above. CMD is the default for an interactive
# `docker run <image>` and is replaced wholesale by any command Nextflow or a
# user supplies.
CMD ["caddsv", "--help"]

###############################################################################
# Stage 5 -- segmentnt: opt-in image with SegmentNT support
#
# Deliberately placed BEFORE the default stage: docker builds the last stage
# when no --target is given, and this one should not be the default.
#
# The model weights themselves are not baked -- they stay on the mounted volume
# under <annotations-dir>/segment_nt, fetched once with `caddsv get segmentnt`.
###############################################################################
FROM runtime-common AS segmentnt

COPY --from=envs-full /opt/caddsv /opt/caddsv

ENV HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1 \
    SEGMENTNT_LOCAL_FILES_ONLY=1 \
    HF_HOME=/var/cache/caddsv/xdg/huggingface

###############################################################################
# Stage 6 -- runtime: the default image (coordinate-based scoring)
#
# ONE COPY. Splitting the runtime env and the rule-env prefix across two COPY
# instructions breaks the hardlinks conda uses to share package files between
# environments, which can multiply the image size several-fold.
###############################################################################
FROM runtime-common AS runtime

COPY --from=envs-core /opt/caddsv /opt/caddsv