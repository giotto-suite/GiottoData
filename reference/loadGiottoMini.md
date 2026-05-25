# loadGiottoMini

This function will automatically load one of the existing mini giotto
objects. These are processed giotto objects that can be used to test
Giotto functions and run examples. If no python path is provided it will
try to find and use the Giotto python environment. Images associated
with the giotto mini objects will be reconnected if possible. Available
datasets are:

- 1\. visium: mini dataset created from the mouse brain sample

- 2\. visium_multisample: mini dataset created from the human prostate
  normal and carcer samples

- 3\. vizgen: mini dataset created from the mouse brain sample

- 4\. cosmx: mini dataset created from the lung12 sample

- 5\. spatialgenomics: mini dataset created from the mouse kidney sample

- 6\. seqfish

- 7\. starmap

Instructions, such as for saving plots, can be changed using the
[`instructions`](https://giotto-suite.github.io/GiottoClass/reference/giotto_instructions.html)

## Usage

``` r
loadGiottoMini(
  dataset = c("visium", "visium_multisample", "seqfish", "starmap", "vizgen", "cosmx",
    "spatialgenomics"),
  python_path = NULL,
  init_gobject = TRUE,
  ...
)
```

## Arguments

- dataset:

  mini dataset giotto object to load

- python_path:

  pythan path to use

- init_gobject:

  logical. Whether to initialize gobject on load

- ...:

  additional params to pass to \`GiottoClass::loadGiotto()\`

## Examples

``` r
loadGiottoMini("visium")
#> 1. read Giotto object
#> 2. read Giotto feature information
#> 3. read Giotto spatial information
#> 4. read Giotto image information
#> checking default envname 'giotto_env'
#> a system default python environment was found
#> Using python path:
#>  "/usr/bin/python3"
#> Warning: Some of Giotto's expected python module(s) were not found:
#> pandas, igraph, leidenalg, community, networkx, sklearn
#> (This is fine if python-based functions are not needed)
#> 
#> ** Python path used: "/usr/bin/python3"
#> An object of class giotto 
#> >Active spat_unit:  cell 
#> >Active feat_type:  rna 
#> dimensions    : 634, 624 (features, cells)
#> [SUBCELLULAR INFO]
#> polygons      : cell 
#> [AGGREGATE INFO]
#> expression -----------------------
#>   [cell][rna] raw normalized scaled
#> spatial locations ----------------
#>   [cell] raw
#> spatial networks -----------------
#>   [cell] Delaunay_network spatial_network
#> spatial enrichments --------------
#>   [cell][rna] cluster_metagene DWLS
#> dim reduction --------------------
#>   [cell][rna] pca custom_pca umap custom_umap tsne
#> nearest neighbor networks --------
#>   [cell][rna] sNN.pca custom_NN
#> attached images ------------------
#> images      : alignment image 
#> 
#> 
#> Use objHistory() to see steps and params used
```
