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

# https://stackoverflow.com/questions/7963898/extracting-the-last-n-characters-from-a-string-in-r
str_tail <- function(x, n) {
    substr(x, nchar(x) - n + 1, nchar(x))
}
