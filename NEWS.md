# GiottoData 0.3.1

## Enhancements
- `getSpatialDataset()` now expands archives at the root of the dataset directory, stripping a single wrapping folder if the archive has one, so the returned path is directly the vendor directory and callers never need to know the archive's internal shape
- Extraction drops macOS packaging noise (`__MACOSX/`, `.DS_Store`, `._*`), so a dataset mirroring a vendor's output layout does not carry resource forks
- The archive is removed once expanded, since it is redundant with its contents. `extract = FALSE` keeps the archive and skips expansion. A hidden `.gdata_extracted.json` records what each archive expanded to, so a dropped archive is not re-downloaded on the next call

# GiottoData 0.3.0

## Breaking changes
- `getSpatialDataset()` now defaults `directory` to a persistent per-user cache (`tools::R_user_dir("GiottoData", "cache")`) instead of `getwd()`, and writes into a `dataset`-named subdirectory of it

## New
- `xenium_mini_lung`: 10X Xenium Human Lung Cancer FFPE subset with multimodal segmentation, from [Zenodo 13207308](https://doi.org/10.5281/zenodo.13207308). Ships as an archive and is extracted on download

## Enhancements
- The spatial dataset manifest is now `inst/extdata/datasets.json` instead of `datasets.txt`. Multi-file categories are json arrays rather than `|`-delimited strings, and a dataset omits categories it has no data for instead of carrying an empty column
- New `listSpatialDatasetNames()` reports the datasets `getSpatialDataset()` can download, read from the manifest rather than a hardcoded list
- New `listSpatialDatasetCategories()` and a `getSpatialDataset(include =)` param to download only some categories of file
- `getSpatialDataset()` expands `.zip`/`.tar*` archives after downloading, for datasets the manifest marks with `"extract": true`. New `extract` param overrides the manifest either way. Re-running skips extraction when the contents are already present
- `getSpatialDataset()` now returns the dataset directory path (invisibly)
- `getSpatialDataset()` skips files that are already downloaded. New `force` param re-downloads them

## Internal
- Internal `.gdata_manifest_dev()` / `.gdata_manifest_write()` / `.gdata_manifest_validate()` let contributors edit the dataset manifest as a nested list rather than by hand-editing json. The writer owns the serialization contract and validates before writing. Not exported: the manifest format is internal
- Added a `testthat` suite. `test-manifest.R` asserts the shipped manifest is valid and that the writer round trips

## Bug fixes
- `getSpatialDataset()` raises R's 60 second download timeout to 3600 for the duration of a download, configurable with the new `timeout` param. Datasets over roughly 100 MB previously failed partway through on an ordinary connection. Note that `timeout` cannot be passed via `...`, as `download.file()` silently ignores it
- Restore `mini_seqFISH`, which was dropped from the dataset table in 525c51e while its name stayed in `getSpatialDataset()`'s accepted values, so it errored with `argument is of length zero`. Its source files were never removed
- Fix `sg_mini_kidney` manifest entry: the row had 3 of 5 fields so it was silently dropped when parsing, and its url 404'd

# GiottoData 0.2.16 (2024/11/19)

## New
- New visium_multisample mini object

# GiottoData 0.2.15

## Changes
- internal replacement of deprecated changeGiottoInstructions -> instructions

# GiottoData 0.2.14 (2024/07/24)

## Bug fixes
- fix `loadSubObjectMini()` loading of image subobjects. [#60](https://github.com/drieslab/GiottoData/issues/60)

## Changes
- code reorganization of mini subobject and mini gobject related functions

# GiottoData 0.2.13 (2024/05/31)

## Changes
- Mini Visium rebuilt for GiottoClass 0.3.2. DWLS results have are also now calculated

# GiottoData 0.2.12.0 (2024/05/22)

## Bug fixes
- fix onload image subobject reconnection when generated from dev directory as opposed to lib directory

## Breaking changes
- `gDataDir()` has been made an internal

## Enhancements
- Additional params can now be passed to `GiottoClass::loadGiotto()` from `loadGiottoMini()` through `...`
- `init_gobject` param for `loadGiottoMini()`

## New
- `generate_mini_subobjects()` for rebuilding the mini subobjects


# GiottoData 0.2.11.0 (2024/05/21)

## Changes
- Mini CosMx rebuilt for GiottoClass 0.3.1
- Mini Visium rebuilt for GiottoClass 0.3.1. Added both the "alignment" and "image" (H&E) images. "image" was also spatially re-aligned
- Mini starmap rebuilt for GiottoClass 0.3.1
