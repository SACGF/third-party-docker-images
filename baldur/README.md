# baldur

This image contains the [baldur](https://github.com/heathsc/baldur) tool. baldur calls variants from mitochondrial ONT data.

baldur has no release tag and no Bioconda package. This image builds commit `47448bd` (version `1.4.1`).

The image also contains these tools from htslib `1.25`:

- `samtools`
- `bgzip` and `tabix`. baldur uses `bgzip` to compress the output VCF.

The baldur blacklist file is at `/usr/local/share/baldur/blacklist.txt`.
