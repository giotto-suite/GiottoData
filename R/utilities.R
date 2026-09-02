#' @title GiottoData cache directory
#' @name giottoDataCache
#' @description
#' Path that \pkg{GiottoData} downloads datasets into. Used as the default
#' `directory` for [getSpatialDataset()] and [getSODBDataset()], both of which
#' skip files already present there, so it accumulates across sessions.
#'
#' The location is resolved in this order:
#' \enumerate{
#'   \item `options(giottodata.cache = )`, when set to a path
#'   \item \code{\link[tools]{R_user_dir}}, which itself honours the
#'   `R_USER_CACHE_DIR` environment variable
#' }
#'
#' The option is seeded as `NULL` on load, so the default is the standard
#' per-user cache location until something sets it.
#'
#' Nothing is created by calling this: it computes a path.
#' @param \dots optional path components appended with `file.path()`
#' @param set character path to use as the cache root, or `NULL` to clear the
#' option and fall back to the default location. When given, the option is set
#' and the new root returned invisibly; `\dots` is ignored.
#' @returns character path. Invisibly when `set` is used.
#' @examples
#' giottoDataCache()
#' giottoDataCache("merfish_preoptic")
#'
#' \dontrun{
#' # point it somewhere with more room, for this session
#' giottoDataCache(set = "~/scratch/giotto-data")
#'
#' # equivalent, and how to set it from an .Rprofile
#' options(giottodata.cache = "~/scratch/giotto-data")
#'
#' # back to the default
#' giottoDataCache(set = NULL)
#'
#' # inspect or clear what has accumulated
#' list.files(giottoDataCache())
#' unlink(giottoDataCache("merfish_preoptic"), recursive = TRUE)
#' }
#' @export
giottoDataCache <- function(..., set) {
    if (!missing(set)) {
        if (!is.null(set)) {
            if (!is.character(set) || length(set) != 1L || is.na(set) ||
                !nzchar(set)) {
                stop("[giottoDataCache] `set` must be a single path, or NULL",
                    call. = FALSE
                )
            }
            set <- path.expand(set)
        }
        options(giottodata.cache = set)
        return(invisible(giottoDataCache()))
    }

    root <- getOption("giottodata.cache")
    if (is.null(root) || !is.character(root) || length(root) != 1L ||
        is.na(root) || !nzchar(root)) {
        root <- tools::R_user_dir("GiottoData", "cache")
    }
    file.path(root, ...)
}


#' @title Get GiottoData paths
#' @name giottodata_paths
#' @description Utility functions to get helpful filepaths within the
#' \pkg{GiottoData} package.
#' @param \dots passed to `file.path()`
NULL


# library paths ####

#' @describeIn giottodata_paths Get the library install path
#' of the package. Should not be used in contexts where package is loaded with
#' `devtools::load_all()`
#' @keywords internal
gdata_libdir <- function(...) {
    file.path(system.file(package = "GiottoData"), ...)
}

#' @describeIn giottodata_paths Get the library path to the mini
#' subobjects directory
#' @keywords internal
gdata_subobject_libdir <- function(...) {
    gdata_libdir("Mini_objects", ...)
}

#' @describeIn giottodata_paths Get the library path to the mini
#' datasets directory
#' @keywords internal
gdata_dataset_libdir <- function(...) {
    gdata_libdir("Mini_datasets", ...)
}



# development paths ####

#' @describeIn giottodata_paths Get the development root path
#' @keywords internal
gdata_devdir <- function(...) {
    file.path(rprojroot::find_package_root_file(), ...)
}

#' @describeIn giottodata_paths Get the development path to the mini
#' subobjects directory
#' @keywords internal
gdata_subobject_devdir <- function(...) {
    gdata_devdir("inst", "Mini_objects", ...)
}


#' @describeIn giottodata_paths Get the development path to the mini
#' datasets directory
#' @keywords internal
gdata_dataset_devdir <- function(...) {
    gdata_devdir("inst", "Mini_datasets", ...)
}

#' @describeIn giottodata_paths Get the development path to the extdata
#' directory
#' @keywords internal
gdata_extdata_devdir <- function(...) {
    gdata_devdir("inst", "extdata", ...)
}

# https://stackoverflow.com/questions/7963898/extracting-the-last-n-characters-from-a-string-in-r
str_tail <- function(x, n) {
    substr(x, nchar(x) - n + 1, nchar(x))
}
