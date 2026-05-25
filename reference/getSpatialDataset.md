# getSpatialDataset

This function will automatically download the spatial locations and
expression matrix for the chosen dataset. These files are already in the
right format to create a Giotto object. If wget is installed on your
machine, you can add 'method = wget' to the parameters to download files
faster.

## Usage

``` r
getSpatialDataset(
  dataset = c("ST_OB1", "ST_OB2", "codex_spleen", "cycif_PDAC", "starmap_3D_cortex",
    "osmfish_SS_cortex", "merfish_preoptic", "mini_seqFISH", "seqfish_SS_cortex",
    "seqfish_OB", "slideseq_cerebellum", "ST_SCC", "scRNA_prostate", "scRNA_mouse_brain",
    "mol_cart_lung_873_C1", "sg_mini_kidney"),
  directory = getwd(),
  verbose = TRUE,
  dryrun = FALSE,
  ...
)
```

## Arguments

- dataset:

  dataset to download

- directory:

  directory to save the data to

- verbose:

  verbosity

- dryrun:

  dryrun: does not download data but shows download commands

- ...:

  additional parameters to
  [`download.file`](https://rdrr.io/r/utils/download.file.html)
