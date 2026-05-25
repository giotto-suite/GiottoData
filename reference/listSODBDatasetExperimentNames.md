# listSODBDatasetExperimentNames

listSODBDatasetExperimentNames

## Usage

``` r
listSODBDatasetExperimentNames(dataset_name = NULL, env_name = "giotto_env")
```

## Arguments

- dataset_name:

  name of dataset for which experiment names will be listed. Must exist
  within the SODB.

- env_name:

  Python environment within which pysodb is installed. If it is not
  already installed, the user will be prompted to install \`pysodb\`
  DEFAULT: "giotto_env"

## Details

Returns a vector containing the names of experiments associated with the
provided \`dataset_name\`.

Run

    listSODBDatasetNames()

to find names of SODB datasets.
