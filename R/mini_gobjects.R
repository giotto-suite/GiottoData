# list of available mini gobjects
# Each entry is named by the dataset it points to.
# Entries contain filepath terms to get to where the data exists.
mini_gobject_manifest <- list(
    "visium" = list("Visium", "VisiumObject"),
    "visium_multisample" = list("Visium_multisample", "VisiumObject"),
    "vizgen" = list("Vizgen", "VizgenObject"),
    "cosmx" = list("CosMx", "CosMxObject"),
    "seqfish" = list("seqfish", "seqfishObject"),
    "starmap" = list("3D_starmap", "3DStarmapObject"),
    "spatialgenomics" = list("SpatialGenomics", "SpatialGenomicsObject")
)




#' @title loadGiottoMini
#' @name loadGiottoMini
#' @param dataset mini dataset giotto object to load
#' @param python_path pythan path to use
#' @param init_gobject logical. Whether to initialize gobject on load
#' @param \dots additional params to pass to `GiottoClass::loadGiotto()`
#' @description This function will automatically load one of the existing mini
#' giotto objects. These are processed giotto objects that can be used to test
#' Giotto functions and run examples. If no python path is provided it will try
#' to find and use the Giotto python environment.
#' Images associated with the giotto mini objects will be reconnected if
#' possible.
#' Available datasets are:
#' \itemize{
#'   \item{1. visium: mini dataset created from the mouse brain sample }
#'   \item{2. visium_multisample: mini dataset created from the human prostate normal and carcer samples }
#'   \item{3. vizgen: mini dataset created from the mouse brain sample }
#'   \item{4. cosmx: mini dataset created from the lung12 sample }
#'   \item{5. spatialgenomics: mini dataset created from the mouse kidney sample}
#'   \item{6. seqfish}
#'   \item{7. starmap}
#' }
#' Instructions, such as for saving plots, can be changed
#' using the \code{\link{instructions}}
#' @examples
#' loadGiottoMini("visium")
#'
#' @export
loadGiottoMini <- function(dataset = c(
        "visium",
        "visium_multisample",
        "seqfish",
        "starmap",
        "vizgen",
        "cosmx",
        "spatialgenomics"
    ),
    python_path = NULL,
    init_gobject = TRUE,
    ...) {
    dataset <- match.arg(dataset, choices = c(
        names(mini_gobject_manifest)
    ))

    load_fun <- function(x) {
        GiottoClass::loadGiotto(
            path_to_folder = x,
            python_path = python_path,
            reconnect_giottoImage = FALSE,
            init_gobject = init_gobject,
            ...
        )
    }

    # use libdir since this function is user-facing
    path <- do.call(gdata_dataset_libdir, mini_gobject_manifest[[dataset]])
    mini_gobject <- load_fun(path)

    # 1. change default instructions
    # Only mini object-specific instructions should be updated here. The python
    # path update was taken care of inside of `loadGiotto()`
    instructions(
        gobject = mini_gobject,
        param = c("show_plot", "return_plot", "save_plot", "save_dir")
    ) <- list(TRUE, FALSE, FALSE, NA)

    return(mini_gobject)
}
