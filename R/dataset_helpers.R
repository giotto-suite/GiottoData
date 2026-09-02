


# Download a set of '|'-delimited urls into `dest_dir`, skipping any file that
# is already present. Downloads go to a `.part` sidecar and are renamed only
# once `download.file()` returns, so an interrupted download is never mistaken
# for a cached one on the next call.
.gdata_fetch <- function(urls,
                         dest_dir,
                         dryrun = FALSE,
                         verbose = TRUE,
                         force = FALSE,
                         skip = character(),
                         ...) {
  urls <- unlist(strsplit(urls, split = '\\|'))
  if (dryrun) {
    for (url in urls) {
      wrap_msg("utils::download.file(url = ", url, ", destfile = ",
               file.path(dest_dir, basename(url)), ", ...)")
    }
    return(invisible(NULL))
  }

  # clear residue from a previously interrupted call, and register cleanup so
  # this call does not leave any of its own behind. Registered once against the
  # whole vector: `on.exit()` evaluates lazily, so a per-iteration registration
  # would resolve every entry to the final loop value.
  partfiles <- file.path(dest_dir, paste0(basename(urls), ".part"))
  on.exit(unlink(partfiles), add = TRUE)
  unlink(partfiles)

  for (url in urls) {
    myfilename <- basename(url)
    mydestfile <- file.path(dest_dir, myfilename)

    if (myfilename %in% skip && !force) {
      if (verbose) wrap_msg("already extracted, skipping download: ", myfilename)
      next
    }

    if (file.exists(mydestfile) && !force) {
      if (verbose) wrap_msg("cached, skipping download: ", myfilename)
      next
    }

    partfile <- paste0(mydestfile, ".part")
    utils::download.file(url = url, destfile = partfile, ...)
    if (!file.rename(partfile, mydestfile)) {
      stop("[getSpatialDataset] unable to move download into place: ",
           mydestfile, call. = FALSE)
    }
  }
}


# Read the dataset manifest. Each dataset is `files` (a named list of
# categories, each a character vector of urls) plus optional dataset-level
# attributes such as `extract`. A dataset simply omits the categories it has no
# data for.
#
# Must be read at call time: top-level code in R/ is evaluated when the
# lazy-load DB is built, and a `system.file()` there bakes the staging path
# into the package, which staged installation rejects.
.gdata_manifest <- function(path = system.file("extdata", "datasets.json",
                                               package = 'GiottoData')) {
    jsonlite::fromJSON(path, simplifyVector = TRUE)
}


# Dev-only counterparts to `.gdata_manifest()`. These read and write the copy
# in the source tree so that a manifest edit can be made as a nested list and
# shipped, without hand-editing json. Never call these at runtime: they resolve
# through rprojroot, which only finds a package root in a source checkout.
.gdata_manifest_dev <- function(path = gdata_extdata_devdir("datasets.json")) {
    .gdata_manifest(path)
}


# Owns the serialization contract so no caller hand-rolls toJSON options:
# categories stay arrays even at length 1, `extract` writes as a bare boolean,
# and `files` always precedes the attributes. Validates before writing and
# re-reads afterwards, because serialization is the step that has silently
# changed this file's shape before.
.gdata_manifest_write <- function(manifest,
                                  path = gdata_extdata_devdir("datasets.json")) {
    .gdata_manifest_validate(manifest)
    orig <- manifest

    for (ds in names(manifest)) {
        if (!is.null(manifest[[ds]][['extract']])) {
            manifest[[ds]][['extract']] <- jsonlite::unbox(manifest[[ds]][['extract']])
        }
        manifest[[ds]] <- manifest[[ds]][
            intersect(c("files", "extract"), names(manifest[[ds]]))
        ]
    }

    writeLines(jsonlite::toJSON(manifest, pretty = 4, auto_unbox = FALSE), path)

    back <- .gdata_manifest(path)
    ok <- identical(names(back), names(orig)) &&
        identical(lapply(back, `[[`, "files"), lapply(orig, `[[`, "files")) &&
        identical(
            vapply(back, function(x) isTRUE(x[['extract']]), logical(1)),
            vapply(orig, function(x) isTRUE(x[['extract']]), logical(1))
        )
    if (!ok) {
        stop("[.gdata_manifest_write] json at ", path,
             " did not read back as written", call. = FALSE)
    }

    invisible(path)
}


# Every bug this manifest has had was a shape bug, so the checks are picky.
# Runs against the shipped json in the test suite, and before any write.
.gdata_manifest_validate <- function(manifest) {
    problems <- character()
    add <- function(...) problems <<- c(problems, paste0(...))

    if (!is.list(manifest) || is.null(names(manifest))) {
        stop("[.gdata_manifest_validate] manifest must be a named list",
             call. = FALSE)
    }
    if (anyDuplicated(names(manifest)) > 0L) {
        add("duplicate dataset name(s): ", paste(
            unique(names(manifest)[duplicated(names(manifest))]), collapse = ", "))
    }
    if (!all(nzchar(names(manifest)))) add("dataset with an empty name")

    for (ds in names(manifest)) {
        entry <- manifest[[ds]]
        if (!is.list(entry)) {
            add(ds, ": entry must be a list")
            next
        }

        unknown <- setdiff(names(entry), c("files", "extract"))
        if (length(unknown) > 0L) {
            add(ds, ": unknown key(s): ", paste(unknown, collapse = ", "))
        }

        ex <- entry[['extract']]
        if (!is.null(ex) && !(is.logical(ex) && length(ex) == 1L && !is.na(ex))) {
            add(ds, ": `extract` must be a single TRUE or FALSE")
        }

        files <- entry[['files']]
        if (!is.list(files) || is.null(names(files)) || length(files) == 0L) {
            add(ds, ": `files` must be a non-empty named list")
            next
        }
        if (!all(nzchar(names(files)))) add(ds, ": category with an empty name")

        for (cat in names(files)) {
            urls <- files[[cat]]
            if (!is.character(urls) || length(urls) == 0L) {
                add(ds, "/", cat, ": must be a non-empty character vector of urls")
                next
            }
            if (anyNA(urls) || !all(nzchar(urls))) {
                add(ds, "/", cat, ": empty or NA url")
                next
            }
            bad <- urls[!grepl("^https?://", urls)]
            if (length(bad) > 0L) {
                add(ds, "/", cat, ": not an http(s) url: ",
                    paste(bad, collapse = ", "))
            }
        }

        # every url for a dataset lands in one flat directory, so a basename
        # repeated across categories would have the files overwrite each other
        bn <- basename(unlist(files, use.names = FALSE))
        if (anyDuplicated(bn) > 0L) {
            add(ds, ": duplicate filename(s) across categories: ",
                paste(unique(bn[duplicated(bn)]), collapse = ", "))
        }
    }

    if (length(problems) > 0L) {
        stop("[.gdata_manifest_validate] invalid manifest:\n  ",
             paste(problems, collapse = "\n  "), call. = FALSE)
    }
    invisible(TRUE)
}


# Every category name used anywhere in the manifest. Data-driven so that adding
# a category to the json needs no change here.
.gdata_categories <- function(manifest = .gdata_manifest()) {
    unique(unlist(lapply(manifest, function(x) names(x$files)), use.names = FALSE))
}


# Archive formats the post-download step expands. Single-file compression
# (.gz, .bz2 on their own) is deliberately absent: several manifest entries are
# .txt.gz count matrices that are meant to stay compressed and be read as-is.
.gdata_archive_type <- function(path) {
    if (grepl("[.]zip$", path, ignore.case = TRUE)) return("zip")
    if (grepl("[.](tar|tgz|tbz|tbz2|taz)$|[.]tar[.](gz|bz2|xz|z)$", path,
              ignore.case = TRUE)) return("tar")
    NA_character_
}


# Archive members that are packaging noise rather than data. Dropped on
# extraction so a fixture that mirrors a vendor's output directory does not
# also carry macOS resource forks.
.gdata_archive_junk <- function(entries) {
    grepl("^__MACOSX/|(^|/)[.]DS_Store$|(^|/)[.]_", entries)
}


# Name of the single directory every real entry sits inside, or NA when the
# archive already unpacks flat. Archives are commonly wrapped in one folder
# (`Raw/...`), which would otherwise leave the vendor layout one level below
# the path `getSpatialDataset()` returns.
.gdata_archive_root <- function(entries) {
    e <- entries[!.gdata_archive_junk(entries)]
    e <- e[nzchar(e)]
    if (length(e) == 0L) return(NA_character_)

    root <- unique(sub("/.*$", "", e))
    if (length(root) != 1L) return(NA_character_)
    # every entry must be the wrapper itself or live under it, and something
    # must actually be inside
    inside <- e[e != root & e != paste0(root, "/")]
    if (length(inside) == 0L) return(NA_character_)
    if (!all(startsWith(inside, paste0(root, "/")))) return(NA_character_)
    root
}


# Record of what each archive expanded to. Written because extraction deletes
# the archive: without it there is no way to tell "already extracted" from
# "never downloaded", and the download step would fetch it again every call.
.gdata_stamp_path <- function(dest_dir) {
    file.path(dest_dir, ".gdata_extracted.json")
}

.gdata_stamp_read <- function(dest_dir) {
    p <- .gdata_stamp_path(dest_dir)
    if (!file.exists(p)) return(list())
    jsonlite::fromJSON(p, simplifyVector = TRUE)
}

.gdata_stamp_write <- function(dest_dir, stamp) {
    writeLines(
        jsonlite::toJSON(stamp, pretty = 4, auto_unbox = FALSE),
        .gdata_stamp_path(dest_dir)
    )
}


# Archives whose recorded contents are all still on disk. These need neither
# re-downloading nor re-extracting.
.gdata_extracted_ok <- function(dest_dir) {
    stamp <- .gdata_stamp_read(dest_dir)
    if (length(stamp) == 0L) return(character())
    ok <- vapply(names(stamp), function(a) {
        e <- stamp[[a]]
        length(e) > 0L && all(file.exists(file.path(dest_dir, e)))
    }, logical(1))
    names(stamp)[ok]
}


# Expand any archives among `files` at the root of `dest_dir`, so the returned
# dataset path is directly the vendor directory. The archive is removed once it
# has expanded: it is redundant with its own contents, and `extract = FALSE`
# is how a caller asks to keep it instead.
.gdata_extract <- function(files, dest_dir, verbose = TRUE, force = FALSE) {
    stamp <- .gdata_stamp_read(dest_dir)

    for (f in files) {
        type <- .gdata_archive_type(f)
        if (is.na(type)) next
        aname <- basename(f)

        if (!force && aname %in% .gdata_extracted_ok(dest_dir)) {
            if (verbose) wrap_msg("already extracted, skipping: ", aname)
            next
        }
        if (!file.exists(f)) next

        listing <- switch(type,
            zip = utils::unzip(f, list = TRUE)[["Name"]],
            tar = utils::untar(f, list = TRUE)
        )
        wanted <- listing[!.gdata_archive_junk(listing)]
        root <- .gdata_archive_root(listing)

        if (verbose) {
            wrap_msg("Extracting ", aname, " (", length(wanted), " entries",
                     if (!is.na(root)) paste0(", stripping '", root, "/'") else "",
                     ")")
        }

        switch(type,
            zip = utils::unzip(f, files = wanted, exdir = dest_dir),
            tar = utils::untar(f, files = wanted, exdir = dest_dir)
        )

        # lift the wrapper's contents up a level, then drop the empty wrapper.
        # A rename within dest_dir stays on one filesystem, so this does not
        # copy the payload.
        if (!is.na(root)) {
            rdir <- file.path(dest_dir, root)
            for (item in list.files(rdir, all.files = TRUE, no.. = TRUE)) {
                file.rename(file.path(rdir, item), file.path(dest_dir, item))
            }
            unlink(rdir, recursive = TRUE)
            # exact prefix removal rather than a regex: a wrapper name is
            # arbitrary vendor text and may hold metacharacters. Every
            # non-junk entry is the wrapper or sits under it, so the cut is
            # unconditional and the wrapper's own entry falls out empty.
            wanted <- substring(wanted, nchar(root) + 2L)
            wanted <- wanted[nzchar(wanted)]
        }

        # keep only paths that actually landed, so the stamp is a truthful
        # record to test against later
        wanted <- wanted[file.exists(file.path(dest_dir, wanted))]
        stamp[[aname]] <- wanted
        .gdata_stamp_write(dest_dir, stamp)

        unlink(f)
    }
}


#' @title List spatial dataset names
#' @name listSpatialDatasetNames
#' @description Names of the datasets that [getSpatialDataset()] can download.
#' Read from the package dataset manifest, which is the single source of truth
#' for both the accepted names and the urls they resolve to.
#' @returns character vector of dataset names
#' @examples
#' listSpatialDatasetNames()
#' @export
listSpatialDatasetNames <- function() {
    names(.gdata_manifest())
}


#' @title List spatial dataset file categories
#' @name listSpatialDatasetCategories
#' @description The kinds of file [getSpatialDataset()] knows how to download,
#' across all datasets. Accepted by that function's `include` param. Any single
#' dataset carries only the categories it actually has data for.
#' @returns character vector of category names
#' @examples
#' listSpatialDatasetCategories()
#' @export
listSpatialDatasetCategories <- function() {
    .gdata_categories()
}


#' @title getSpatialDataset
#' @name getSpatialDataset
#' @param dataset dataset to download. One of [listSpatialDatasetNames()]
#' @param directory directory to save the data to. Datasets are placed in a
#' subdirectory named after `dataset`. Defaults to [giottoDataCache()], a
#' persistent per-user location.
#' @param verbose verbosity
#' @param dryrun dryrun: does not download data but shows download commands
#' @param force logical. Re-download files that are already present
#' @param include character. Which categories of file to download. Defaults to
#' all of [listSpatialDatasetCategories()]. Categories a dataset has no data
#' for are skipped.
#' @param extract logical or NULL. Whether to expand downloaded `.zip`/`.tar*`
#' archives after downloading. `NULL` (default) follows the manifest, which sets
#' this per dataset. `TRUE`/`FALSE` overrides it. Contents are placed at the
#' root of the dataset directory, stripping a single wrapping folder if the
#' archive has one, so the returned path is directly usable. The archive itself
#' is removed once expanded, since it is redundant with its contents; pass
#' `extract = FALSE` to keep the archive instead. Re-running skips archives
#' whose contents are already present.
#' @param timeout numeric or NULL. Seconds before a download is abandoned.
#' `NULL` (default) raises R's 60 second default to 3600 for the duration of
#' the call, without lowering a larger existing `options(timeout =)`. A number
#' is used as given. Note that this cannot be passed through `\dots`, since
#' `download.file()` silently ignores an argument of this name.
#' @param \dots additional parameters to \code{\link[utils]{download.file}}
#' @description This function will automatically download the spatial locations
#' and expression matrix for the chosen dataset. These files are already in the
#' right format to create a Giotto object. If wget is installed on your machine,
#' you can add 'method = wget' to the parameters to download files faster.
#'
#' Downloads are cached: files already present in the target directory are not
#' re-downloaded unless `force = TRUE`, so repeat calls for the same dataset
#' return immediately.
#' @returns character. Path to the directory the dataset files were written to,
#' returned invisibly.
#' @export
getSpatialDataset <- function(dataset = listSpatialDatasetNames(),
                              directory = giottoDataCache(),
                              verbose = TRUE,
                              dryrun = FALSE,
                              force = FALSE,
                              include = listSpatialDatasetCategories(),
                              extract = NULL,
                              timeout = NULL,
                              ...) {
    # R's 60 second default is shorter than a several hundred MB dataset takes
    # on an ordinary connection. `timeout` cannot be passed through `...`,
    # because `download.file()` accepts and silently ignores it: it is an
    # option, not an argument. NULL raises a floor without lowering a caller's
    # larger setting.
    if (is.null(timeout)) timeout <- max(3600, getOption("timeout"))

    datasets_file <- .gdata_manifest()
    sel_dataset <- match.arg(arg = dataset, choices = names(datasets_file))
    include <- match.arg(
        arg = include,
        choices = .gdata_categories(datasets_file),
        several.ok = TRUE
    )

    # each dataset gets its own subdirectory so that datasets sharing a
    # filename cannot collide, and so that the returned path is meaningful
    # without also knowing which dataset was requested
    dest_dir <- file.path(directory, sel_dataset)
    if (!file.exists(dest_dir)) {
        vmsg(.v = verbose, "Creating dataset directory: ", dest_dir)
        dir.create(dest_dir, recursive = TRUE)
    }

    selected_dataset_info <- datasets_file[[sel_dataset]][["files"]]

    # the manifest decides whether a dataset ships as an archive. An explicit
    # `extract` overrides it in either direction.
    if (is.null(extract)) {
        extract <- isTRUE(datasets_file[[sel_dataset]][["extract"]])
    }

    # only the categories this dataset actually carries, in manifest order
    fetch_cats <- intersect(names(selected_dataset_info), include)

    if (verbose) {
        wrap_msg("Selected dataset links for: ", sel_dataset)
        for (cat in fetch_cats) {
            wrap_msg(
                "  ", cat, ": ",
                length(selected_dataset_info[[cat]]), " file(s)"
            )
        }
        skipped <- setdiff(include, fetch_cats)
        if (length(skipped) > 0L) {
            wrap_msg(
                "  not available for this dataset: ",
                paste(skipped, collapse = ", ")
            )
        }
    }

    # archives already expanded here were deleted afterwards, so their absence
    # is not a reason to download them again
    already <- if (extract && !force) .gdata_extracted_ok(dest_dir) else character()

    GiottoUtils::gwith_options(list(timeout = timeout), {
        for (cat in fetch_cats) {
            vmsg(.v = verbose, "\n Download ", cat, ": \n")
            .gdata_fetch(selected_dataset_info[[cat]], dest_dir,
                dryrun = dryrun,
                verbose = verbose,
                force = force,
                skip = already,
                ...
            )
        }
    })

    if (extract && length(fetch_cats) > 0L) {
        fetched <- file.path(
            dest_dir,
            basename(unlist(selected_dataset_info[fetch_cats]))
        )
        if (dryrun) {
            archives <- fetched[
                !is.na(vapply(fetched, .gdata_archive_type, character(1)))
            ]
            if (length(archives) > 0L) {
                wrap_msg("would extract: ",
                         paste(basename(archives), collapse = ", "))
            }
        } else {
            .gdata_extract(fetched, dest_dir, verbose = verbose, force = force)
        }
    }

    return(invisible(dest_dir))
}

#' @title listSODBDatasetNames
#' @name listSODBDatasetNames
#' @param category name of category for which dataset names will be listed.
#' @param env_name Python environment within which pysodb is installed.
#' If it is not already installed, the user
#' will be prompted to install `pysodb`
#' DEFAULT: "giotto_env"
#' @details Returns a vector containing the names of datasets associated with
#' the provided `category`.
#' @export
listSODBDatasetNames <- function(category = c(
        "All",
        "Spatial Transcriptomics",
        "Spatial Proteomics",
        "Spatial Metabolomics",
        "Spatial Genomics",
        "Spatial MultiOmics"
    ),
    env_name = "giotto_env") {
    pysodb_installed <- GiottoClass:::checkPythonPackage(
        package_name = "pysdob",
        env_to_use = env_name
    )

    if (!pysodb_installed) {
        GiottoClass:::checkPythonPackage(
            github_package_url = "git+https://github.com/TencentAILabHealthcare/pysodb.git",
            env_to_use = env_name
        )
    }

    sel_category <- match.arg(arg = category, choices = c(
        "All",
        "Spatial Transcriptomics",
        "Spatial Proteomics",
        "Spatial Metabolomics",
        "Spatial Genomics",
        "Spatial MultiOmics"
    ))

    # Import interface_sodb, a python module for importing data from SODB
    interface_sodb <- system.file("python",
        "interface_sodb.py",
        package = "GiottoData"
    )
    reticulate::source_python(interface_sodb)

    sodb_dataset_names <- list_SODB_datasets(category = sel_category)

    return(sodb_dataset_names)
}

#' @title listSODBDatasetExperimentNames
#' @name listSODBDatasetExperimentNames
#' @param dataset_name name of dataset for which experiment names will be listed.
#'        Must exist within the SODB.
#' @param env_name Python environment within which pysodb is installed.
#' If it is not already installed, the user
#' will be prompted to install `pysodb`
#' DEFAULT: "giotto_env"
#' @details
#' Returns a vector containing the names of experiments associated with
#' the provided `dataset_name`.
#'
#' Run \preformatted{listSODBDatasetNames()} to find names of SODB datasets.
#' @export
listSODBDatasetExperimentNames <- function(dataset_name = NULL,
    env_name = "giotto_env") {
    pysodb_installed <- GiottoClass:::checkPythonPackage(
        package_name = "pysdob",
        env_to_use = env_name
    )

    if (!pysodb_installed) {
        GiottoClass:::checkPythonPackage(
            github_package_url = "git+https://github.com/TencentAILabHealthcare/pysodb.git",
            env_to_use = env_name
        )
    }

    if (is.null(dataset_name)) {
        stop(GiottoUtils::wrap_txt("A dataset name must be provided.
                               Run `listSODBDatasetNames()` for dataset names.",
            errWidth = TRUE
        ))
    }
    # Import interface_sodb, a python module for importing data from SODB
    interface_sodb <- system.file("python",
        "interface_sodb.py",
        package = "GiottoData"
    )
    reticulate::source_python(interface_sodb)

    sodb_dataset_experiment_names <- list_SODB_dataset_experiments(dataset_name = dataset_name)

    return(sodb_dataset_experiment_names)
}

#' @title getSODBDataset
#' @name getSODBDataset
#' @param dataset_name name of dataset to pull from the SODB.
#'        Must exist within the SODB.
#' @param experiment_name name of one experiment associated with `dataset_name`
#'        By default, the first experiment will be used.
#' @param env_name name of the conda environment within which
#'        pysodb is already installed, or within which installation
#'        of pysodb will be prompted
#' @details
#' Interface with the Spatial Omics DataBase (SODB) using the
#' python extension, pysodb, from TenCent.
#'
#' This function will write an anndata h5ad file for a provided dataset
#' name to the current working directory and will then  convert
#' the h5ad into a Giotto Object.
#'
#' Run \preformatted{listSODBDatasetNames()} to find names of SODB datasets.
#' Run \preformatted{listSODBDatasetExperimentNames()} to find names of
#' experiments associate with a provided dataset.
#'
#' This function will not run if pysodb is not installed in
#' the active conda environment. It will prompt the user to install
#' pysodb automatically if it is not detected.
#'
#' *Note that manual installation is more stable.*
#' To install manually within the giotto environment, follow the steps below:
#'
#' 1. Run \preformatted{checkGiottoEnvironment()} in R to find
#' the installation location of the Giotto conda environment.
#'
#' 2. Open a terminal.
#'
#' 3. Clone the source code and change into the pysodb directory.
#'
#' \preformatted{
#'   git clone https://github.com/TencentAILabHealthcare/pysodb.git
#'   cd pysodb
#' }
#'
#' 4. Activate the giotto environment.
#'
#' \preformatted{conda activate your/path/to/giotto_env}
#'
#' 5. Install pysodb as a dependency or third-party package with pip:
#'
#' \preformatted{pip install .}
#'
#' @examples
#' \dontrun{
#'
#' sodb_dataset_names <- listSODBDatasetNames()
#' desired_dataset <- sodb_dataset_names[[15]] # Arbitrary
#'
#' dataset_experiment_names <- listSODBDatasetExperimentNames(dataset_name = desired_dataset)
#' desired_experiment <- dataset_experiment_names[[1]] # Arbitrary
#'
#' gobject <- getSODBDataset(
#'     dataset_name = desired_dataset,
#'     experiment_name = desired_experiment
#' )
#' }
#' @export
getSODBDataset <- function(dataset_name = NULL,
    experiment_name = "default",
    env_name = "giotto_env") {
    pysodb_installed <- GiottoClass:::checkPythonPackage(
        package = "pysodb",
        env_to_use = env_name
    )
    if (!pysodb_installed) {
        GiottoClass:::checkPythonPackage(
            github_package_url = "git+https://github.com/TencentAILabHealthcare/pysodb.git",
            env_to_use = env_name
        )
        # not returning value to variable because this
        # will crash downstream if unsuccessful.
    }
    if (is.null(dataset_name)) {
        stop(GiottoUtils::wrap_txt("A dataset name must be provided.
                               Run `listSODBDatasetNames()` for dataset names.",
            errWidth = TRUE
        ))
    }
    # Import interface_sodb, a python module for importing data from SODB
    interface_sodb <- system.file("python",
        "interface_sodb.py",
        package = "GiottoData"
    )

    reticulate::source_python(interface_sodb)

    # Try to get data from SODB using provided dataset and experiment names
    sodb_adata <- get_SODB_dataset(
        dataset_name = dataset_name,
        experiment_name = experiment_name
    )

    # Check validity of returned anndata object.
    # Nothing will happen if it passes
    # A python error will be thrown otherwise
    check_SODB_adata(
        dataset_name = dataset_name,
        adata = sodb_adata,
        experiment_name = experiment_name
    )

    sodb_adata$write_h5ad("./SODB_dataset_for Giotto.h5ad")

    gobject <- Giotto::anndataToGiotto(anndata_path = "./SODB_dataset_for Giotto.h5ad")

    return(gobject)
}
