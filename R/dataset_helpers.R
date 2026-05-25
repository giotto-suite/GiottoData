#' @title getSpatialDataset
#' @name getSpatialDataset
#' @param dataset dataset to download
#' @param directory directory to save the data to
#' @param verbose verbosity
#' @param dryrun dryrun: does not download data but shows download commands
#' @param \dots additional parameters to \code{\link[utils]{download.file}}
#' @description This function will automatically download the spatial locations and
#' expression matrix for the chosen dataset. These files are already in the right format
#' to create a Giotto object. If wget is installed on your machine, you can add
#' 'method = wget' to the parameters to download files faster.
#' @export
getSpatialDataset <- function(dataset = c(
        "ST_OB1",
        "ST_OB2",
        "codex_spleen",
        "cycif_PDAC",
        "starmap_3D_cortex",
        "osmfish_SS_cortex",
        "merfish_preoptic",
        "mini_seqFISH",
        "seqfish_SS_cortex",
        "seqfish_OB",
        "slideseq_cerebellum",
        "ST_SCC",
        "scRNA_prostate",
        "scRNA_mouse_brain",
        "mol_cart_lung_873_C1",
        "sg_mini_kidney"
    ),
    directory = getwd(),
    verbose = TRUE,
    dryrun = FALSE,
    ...) {
    sel_dataset <- match.arg(arg = dataset, choices = c(
        "ST_OB1",
        "ST_OB2",
        "codex_spleen",
        "cycif_PDAC",
        "starmap_3D_cortex",
        "osmfish_SS_cortex",
        "merfish_preoptic",
        "mini_seqFISH",
        "seqfish_SS_cortex",
        "seqfish_OB",
        "slideseq_cerebellum",
        "ST_SCC",
        "scRNA_prostate",
        "scRNA_mouse_brain",
        "mol_cart_lung_873_C1",
        "sg_mini_kidney"
    ))

    # check operating system first
    os_specific_system <- get_os()

    # if(os_specific_system == 'windows') {
    #  stop('This function is currently not supported on windows systems,
    #       please visit https://github.com/RubD/spatial-datasets and manually download your files')
    # }


    # check directory
    if (!file.exists(directory)) {
        warning("The output directory does not exist and will be created \n")
        dir.create(directory, recursive = TRUE)
    }

    datasets_file <- system.file("extdata", "datasets.txt", package = "GiottoData")
    datasets_file <- data.table::fread(datasets_file, sep = "\t")



    ## check if wget is installed
    # message = system("if ! command -v wget &> /dev/null
    #                  then
    #                  echo 'wget could not be found, please install wget first'
    #                  exit
    #                  fi", intern = TRUE)

    # if(identical(message, character(0))) {
    #  print('wget was found, start downloading datasets: ')
    # } else {
    #  stop(message)
    # }

    ## alternative
    # wget_works = try(system('command -v wget', intern = T))

    # if(class(wget_works) == 'try-error' | is.na(wget_works[1])) {
    #  stop('wget was not found, please install wget first \n')
    # } else {
    #  print('wget was found, start downloading datasets: \n')
    # }

    selection <- datasets_file[["dataset"]] == sel_dataset
    selected_dataset_info <- datasets_file[selection, ]
    if (verbose) {
        wrap_msg("Selected dataset links for: ", sel_dataset, " \n \n")
        print(selected_dataset_info)
    }



    # get url to expression matrix and download
    if (verbose) {
        wrap_msg("\n \n Download expression matrix: \n")
    }
    expr_matrix_url <- selected_dataset_info[["expr_matrix"]]

    if (expr_matrix_url == "") {
        wrap_msg("\n No expression found, skip this step \n")
    } else {
        expr_matrix_url <- unlist(strsplit(expr_matrix_url, split = "\\|"))

        for (url in expr_matrix_url) {
            myfilename <- basename(url)
            mydestfile <- paste0(directory, "/", myfilename)

            if (dryrun) {
                wrap_msg("utils::download.file(url = ", url, ", destfile = ", mydestfile, ", ...)")
            } else {
                utils::download.file(url = url, destfile = mydestfile, ...)
            }
        }
    }






    # get url to spatial locations and download
    if (verbose) {
        wrap_msg("\n \n Download spatial locations: \n")
    }

    spatial_locs_url <- selected_dataset_info[["spatial_locs"]]

    if (spatial_locs_url == "") {
        wrap_msg("\n No spatial locations found, skip this step \n")
    } else {
        spatial_locs_url <- unlist(strsplit(spatial_locs_url, split = "\\|"))

        for (url in spatial_locs_url) {
            myfilename <- basename(url)
            mydestfile <- paste0(directory, "/", myfilename)

            if (dryrun) {
                wrap_msg("utils::download.file(url = ", url, ", destfile = ", mydestfile, ", ...)")
            } else {
                utils::download.file(url = url, destfile = mydestfile, ...)
            }
        }
    }





    # get url(s) to additional metadata files and download
    if (verbose) {
        wrap_msg("\n \n Download metadata: \n")
    }

    # metadata_url = selected_dataset_info[['metadata']][[1]]
    metadata_url <- selected_dataset_info[["metadata"]]

    if (metadata_url == "") {
        wrap_msg("\n No metadata found, skip this step \n")
    } else {
        metadata_url <- unlist(strsplit(metadata_url, split = "\\|"))

        for (url in metadata_url) {
            myfilename <- basename(url)
            mydestfile <- paste0(directory, "/", myfilename)

            if (dryrun) {
                wrap_msg("utils::download.file(url = ", url, ", destfile = ", mydestfile, ", ...)")
            } else {
                utils::download.file(url = url, destfile = mydestfile, ...)
            }
        }
    }






    spatial_seg_url <- selected_dataset_info[["segmentations"]]

    if (spatial_seg_url == "") {
        # wrap_msg('\n No segmentations found, skip this step \n')
    } else {
        if (verbose) {
            wrap_msg("\n \n Download segmentations: \n")
        }

        spatial_seg_url <- unlist(strsplit(spatial_seg_url, split = "\\|"))

        for (url in spatial_seg_url) {
            myfilename <- basename(url)
            mydestfile <- paste0(directory, "/", myfilename)

            if (dryrun) {
                wrap_msg("utils::download.file(url = ", url, ", destfile = ", mydestfile, ", ...)")
            } else {
                utils::download.file(url = url, destfile = mydestfile, ...)
            }
        }
    }
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
