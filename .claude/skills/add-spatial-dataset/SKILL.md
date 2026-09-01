---
name: add-spatial-dataset
description: Add, edit, or remove a dataset in GiottoData's spatial dataset manifest (inst/extdata/datasets.json) so getSpatialDataset() can download it. Use when a contributor wants to make a new spatial dataset downloadable, change a dataset's urls, mark a dataset as an archive to extract, or fix a broken dataset entry.
---

# Add a spatial dataset to GiottoData

`getSpatialDataset()` is driven entirely by `inst/extdata/datasets.json`. Adding a
dataset means adding an entry to that manifest — no R code changes.

**Never hand-edit the json.** Edit it as a nested R list through the internal
writer, which owns the serialization contract and validates before writing.
Hand-editing is how this file previously shipped a row that silently vanished
when parsed.

## Manifest shape

```json
{
  "dataset_name": {
    "files": {
      "spatial_locs": ["https://..."],
      "expr_matrix":  ["https://...", "https://..."]
    },
    "extract": true
  }
}
```

- `files` — named list of category → character vector of urls. A dataset omits
  categories it has no data for. There is no empty-string placeholder.
- Categories are free-form. Reuse an existing one where it fits; see
  `listSpatialDatasetCategories()`. `bundle` is the convention for a
  whole-dataset archive that does not decompose into the other categories.
- `extract` — optional. `true` means expand downloaded `.zip`/`.tar*` archives
  after download. Omit it otherwise.

## Procedure

1. **Verify every url resolves before adding it.** A 404 in the manifest is
   invisible until a user hits it.

   ```bash
   curl -s -o /dev/null -w "%{http_code} %{size_download}\n" -L "<url>"
   ```

   For a GitHub blob, the download form is
   `https://raw.githubusercontent.com/<org>/<repo>/<ref>/<path>`. A
   `https://github.com/<org>/<repo>/<path>` url without `/raw/<ref>/` or the
   `raw.` host will 404.

   For Zenodo, use `https://zenodo.org/records/<id>/files/<filename>` and
   **omit any `?download=1` suffix**. The downloader names the local file with
   `basename(url)`, so a query string would be written into the filename.

   Zenodo also publishes a checksum per file, worth recording in the PR
   description:

   ```bash
   curl -s "https://zenodo.org/api/records/<id>" \
     | python3 -c "import json,sys; [print(f['key'], f['size'], f.get('checksum')) for f in json.load(sys.stdin)['files']]"
   ```

2. **Edit the manifest as a list and write it back.** Run from the package root.

   ```r
   pkgload::load_all(".")

   m <- GiottoData:::.gdata_manifest_dev()

   m$my_dataset <- list(
       files = list(
           spatial_locs = "https://.../coord.txt",
           expr_matrix  = "https://.../expr.txt.gz",
           metadata     = c("https://.../annot.txt", "https://.../celltypes.csv")
       )
   )
   # only for datasets that ship as a .zip / .tar*
   # m$my_dataset$extract <- TRUE

   GiottoData:::.gdata_manifest_write(m)
   ```

   `.gdata_manifest_write()` validates first and refuses to write an invalid
   manifest, then re-reads the file to confirm it parses back as intended.

3. **Test the real download**, not just the dryrun. Use a temp directory so you
   do not pollute the user cache.

   ```r
   pkgload::load_all(".")
   d <- file.path(tempdir(), "check")
   p <- getSpatialDataset("my_dataset", directory = d, verbose = TRUE)
   list.files(p, recursive = TRUE)
   file.size(list.files(p, full.names = TRUE))   # nothing should be 0 bytes
   getSpatialDataset("my_dataset", directory = d)  # must be a fast cache hit
   ```

4. **Run the manifest tests.**

   ```r
   testthat::test_file("tests/testthat/test-manifest.R")
   ```

5. **Add a NEWS.md bullet** under the current version's `## Enhancements`.

## Constraints the validator enforces

`.gdata_manifest_validate()` will reject a write that breaks any of these, so
read the error rather than working around it:

- `files` must be a non-empty named list; every category a non-empty character
  vector with no `NA` or empty strings.
- Urls must be `http://` or `https://`.
- `extract` must be a single `TRUE`/`FALSE` if present.
- No unknown dataset-level keys — only `files` and `extract`. This catches typos
  like `extrct`.
- **Filenames must be unique across categories within a dataset.** All of a
  dataset's files land in one flat directory, so two urls ending in the same
  basename would overwrite each other.

## Gotchas

- **Large datasets take minutes, and that is expected.** `.gdata_fetch()` raises
  R's default 60 second timeout for the duration of a download, so do not
  interpret a long-running fetch as a hang. A 218 MB Zenodo archive takes
  roughly 4 minutes. An interrupted download leaves no `.part` residue and the
  next call resumes from scratch cleanly.
- **`.txt.gz` is not an archive.** Only `.zip` and `.tar*` are expanded. Several
  expression matrices are gzipped and meant to be read compressed — do not set
  `extract` hoping to gunzip them.
- **Do not add a dataset name anywhere but the manifest.** `getSpatialDataset()`
  and `listSpatialDatasetNames()` both derive from it. There is no second list
  to keep in sync, and adding one would reintroduce the drift bug that made
  `mini_seqFISH` unusable.
- **Urls point at mutable branches.** Most current entries use `/master/`, so
  the bytes can change under a fixed url. Prefer a commit SHA in place of the
  branch for anything new. Files over ~50 MB should go to a GitHub Release or
  Zenodo rather than into the repo, since GitHub hard-rejects blobs over 100 MB
  and repo history keeps every revision forever.
- **`.gdata_manifest_dev()` and `.gdata_manifest_write()` are dev-only.** They
  resolve through `rprojroot` and only work in a source checkout. Runtime code
  uses `.gdata_manifest()`, which reads the installed copy.

## Removing or editing a dataset

Same read/modify/write cycle:

```r
m <- GiottoData:::.gdata_manifest_dev()
m$old_dataset <- NULL                                  # remove
m$other$files$metadata <- "https://.../new_meta.csv"   # edit
GiottoData:::.gdata_manifest_write(m)
```

Removing a name is a **breaking change** for users calling
`getSpatialDataset("old_dataset")`. Note it under `## Breaking changes` in
NEWS.md and say what to use instead.