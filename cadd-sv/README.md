# cadd-sv

Container for [CADD-SV](https://github.com/kircherlab/CADD-SV), which scores
the predicted effect of structural variants.

## What is and isn't in the image

Baked in:

- the `caddsv` CLI and Snakemake, from bioconda
- `conda`, which Snakemake needs to activate rule environments
- the per-rule conda environments for coordinate-based scoring, pre-created at
  build time so a run never solves or downloads an environment

Not baked in, mount instead:

- the annotation bundle (tens of GB) -> `/annotations`
- your input and output files -> `/data`
- SegmentNT model weights, for the `segmentnt` image only

## Fetching the annotations (once, on the host)

```bash
docker run --rm -v /data/caddsv/annotations:/annotations \
  ghcr.io/<owner>/third-party/caddsv:2.0 \
  get annotations --annotations-dir /annotations
```

## Scoring

```bash
docker run --rm \
  -v /data/caddsv/annotations:/annotations:ro \
  -v "$PWD":/data \
  ghcr.io/<owner>/third-party/caddsv:2.0 \
  run variants.bed --annotations-dir /annotations -o results --threads 8
```

Results land in `results/scored/variants_score.tsv`.

Input BED needs at least four tab-separated columns (`chrom start end type`),
GRCh38 coordinates, SV type one of DEL/DUP/INS/INV, and variants of at least
50 bp. The CLI normalises chromosome names and sorting before running.

## SegmentNT modes

`--seqresolved` and `--seqonly` need the SegmentNT rule environments (PyTorch,
several GB), which are deliberately excluded from the default image. Build the
opt-in variant locally:

```bash
docker build --target segmentnt -t caddsv:2.0-segmentnt .
```

The model weights are still not baked -- fetch them onto the annotation volume:

```bash
docker run --rm -v /data/caddsv/annotations:/annotations \
  caddsv:2.0-segmentnt get segmentnt --annotations-dir /annotations
```

The CI workflow builds the last Dockerfile stage, which is the slim `runtime`
one, so this variant is not published automatically.

## HPC / Apptainer

```bash
apptainer build caddsv.sif docker://ghcr.io/<owner>/third-party/caddsv:2.0
apptainer run --cleanenv \
  --bind /data/caddsv/annotations:/annotations:ro \
  --bind "$PWD":/data \
  caddsv.sif run variants.bed --annotations-dir /annotations -o /data/results
```

`--cleanenv` matters: Apptainer inherits the host environment by default, which
can shadow `CADD_SV_CONDA_PREFIX` and trigger a full rebuild of the pre-baked
conda environments.

Apptainer runs as your UID rather than any UID baked into the image. Nothing in
the image depends on `$HOME` or on a specific UID: conda's writable locations
are pinned to `/var/cache/caddsv`, which is world-writable, and `caddsv` is
symlinked into `/usr/local/bin` in case `PATH` is rebuilt from the executor's
defaults rather than the image config.

## Nextflow

The image is built for Nextflow's execution model: no `ENTRYPOINT`, no baked-in
`USER`, and `caddsv` on the default `PATH` with no activation step. A process
body can call it directly.

```groovy
process CADDSV_SCORE {
    container 'ghcr.io/<owner>/third-party/caddsv:2.0'
    containerOptions "-v ${params.annotations}:/annotations:ro"

    input:
    path bed

    output:
    path "results/scored/*_score.tsv", emit: scores

    script:
    """
    caddsv run ${bed} \\
      --annotations-dir /annotations \\
      --output-dir results \\
      --threads ${task.cpus}
    """
}
```

With the Singularity/Apptainer executor use `--bind` instead, or set
`singularity.runOptions = "--bind ${params.annotations}:/annotations:ro"`.

Note that `caddsv run` writes Snakemake intermediates under `--output-dir`,
which sits inside the task work directory -- so Nextflow's caching and cleanup
behave normally. Do not point `--output-dir` at a shared location.

## Debugging

```bash
docker run --rm -it <image> bash
```

## Gotchas

- `CADD_SV_CONDA_PREFIX` must stay at `/opt/caddsv/conda-envs`. Snakemake hashes
  the env spec together with the prefix path, so a different prefix silently
  rebuilds every environment on first run. Nothing warns you -- it just gets
  slow. Do not override it in `containerOptions` or `runOptions`.
- There is no `ENTRYPOINT` by design. Adding one breaks Nextflow, which passes
  `/bin/bash -ue .command.sh` as arguments to whatever the image defines.
- First run against a fresh annotation volume is still slow -- the workflow
  transforms annotation files on first use even though the environments exist.
- `--threads` is the Snakemake core count; several rules are I/O-bound.