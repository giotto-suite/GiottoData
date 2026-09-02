#' @title GiottoData cache directory
#' @name giottoDataCache
#' @description
#' Path that \pkg{GiottoData} downloads datasets into. Used as the default
#' `directory` for [getSpatialDataset()] and [getSODBDataset()], both of which
#' skip files already present there, so it accumulates across sessions.
#'
#' The location follows \code{\link[tools]{R_user_dir}} and can be relocated
#' by setting the `R_USER_CACHE_DIR` environment variable, which is how a CI
#' job would point it at a restorable cache.
#'
#' Nothing is created by calling this: it computes a path.
#' @param \dots optional path components appended with `file.path()`
#' @returns character path
#' @examples
#' giottoDataCache()
#'
#' # inspect or clear what has accumulated
#' \dontrun{
#' list.files(giottoDataCache())
#' unlink(giottoDataCache("merfish_preoptic"), recursive = TRUE)
#' }
#' @export
giottoDataCache <- function(...) {
    file.path(tools::R_user_dir("GiottoData", "cache"), ...)
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
