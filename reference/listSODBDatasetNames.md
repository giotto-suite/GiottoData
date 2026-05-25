# listSODBDatasetNames

listSODBDatasetNames

## Usage

``` r
listSODBDatasetNames(
  category = c("All", "Spatial Transcriptomics", "Spatial Proteomics",
    "Spatial Metabolomics", "Spatial Genomics", "Spatial MultiOmics"),
  env_name = "giotto_env"
)
```

## Arguments

- category:

  name of category for which dataset names will be listed.

- env_name:

  Python environment within which pysodb is installed. If it is not
  already installed, the user will be prompted to install \`pysodb\`
  DEFAULT: "giotto_env"

## Details

Returns a vector containing the names of datasets associated with the
provided \`category\`.
