# Get GiottoData paths

Utility functions to get helpful filepaths within the GiottoData
package.

## Usage

``` r
gdata_libdir(...)

gdata_subobject_libdir(...)

gdata_dataset_libdir(...)

gdata_devdir(...)

gdata_subobject_devdir(...)

gdata_dataset_devdir(...)
```

## Arguments

- ...:

  passed to \`file.path()\`

## Functions

- `gdata_libdir()`: Get the library install path of the package. Should
  not be used in contexts where package is loaded with
  \`devtools::load_all()\`

- `gdata_subobject_libdir()`: Get the library path to the mini
  subobjects directory

- `gdata_dataset_libdir()`: Get the library path to the mini datasets
  directory

- `gdata_devdir()`: Get the development root path

- `gdata_subobject_devdir()`: Get the development path to the mini
  subobjects directory

- `gdata_dataset_devdir()`: Get the development path to the mini
  datasets directory
