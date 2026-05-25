## MINI VISIUM MULTISAMPLE script and dataset preparation ##

library(Giotto)

# 0. Subset the original dataset ####
# ----------------- #

## create instructions
instructions <- createGiottoInstructions(
    save_dir = tempdir(),
    save_plot = FALSE,
    show_plot = TRUE,
    return_plot = FALSE
)

N_pros <- createGiottoVisiumObject(
    visium_dir = "data/normal/",
    expr_data = "raw",
    png_name = "tissue_lowres_image.png",
    gene_column_index = 2,
    instructions = instructions
)

C_pros <- createGiottoVisiumObject(
    visium_dir = "data/cancer/",
    expr_data = "raw",
    png_name = "tissue_lowres_image.png",
    gene_column_index = 2,
    instructions = instructions
)

testcombo <- joinGiottoObjects(
    gobject_list = list(N_pros, C_pros),
    gobject_names = c("NP", "CP"),
    join_method = "shift",
    x_padding = 1000
)

# subset on in-tissue spots
metadata <- pDataDT(testcombo)
in_tissue_barcodes <- metadata[in_tissue == 1]$cell_ID

testcombo <- subsetGiotto(testcombo,
    cell_ids = in_tissue_barcodes
)

## subset cells
spatial_locs <- getSpatialLocations(testcombo,
    output = "data.table"
)

spatial_locs <- spatial_locs[spatial_locs$sdimy > -10000, ]
spatial_locs <- spatial_locs[spatial_locs$sdimx < 15000 || spatial_locs$sdimx > 45000, ]

testcombo <- subsetGiotto(testcombo,
    cell_ids = spatial_locs$cell_ID
)

## subset features
testcombo <- normalizeGiotto(testcombo,
                             scale_feats = FALSE,
                             scale_cells = FALSE)

testcombo <- calculateHVF(gobject = testcombo)

x <- getFeatureMetadata(testcombo, 
                        output = "data.table")

x <- x[x$hvf == "yes",]

raw_expression <- getExpression(testcombo,
    values = "raw",
    output = "matrix"
)

raw_expression <- raw_expression[x$feat_ID,]

cell_metadata <- pDataDT(testcombo)

data_path <- system.file("/Mini_datasets/Visium_multisample/Raw/",
    package = "GiottoData"
)

write.table(as.matrix(raw_expression),
    file.path(data_path, "expression_matrix.txt"),
    row.names = TRUE
)

write.table(spatial_locs,
    file.path(data_path, "spatial_locs.txt"),
    row.names = FALSE
)

write.table(cell_metadata,
    file.path(data_path, "cell_metadata.txt"),
    row.names = FALSE
)


# 1. create visium dataset ####
# ------------------------------------------------------------------------ #

## 1.1 path to expression matrix ####
# --------------------------- #
expr_path <- file.path(data_path, "expression_matrix.txt.gz")

## 1.1 path to spot locations ####
# -------------------------------------- #
locations_path <- file.path(data_path, "spatial_locs.txt")

## 1.4 path to metadata ####
# -------------------------------------- #
meta_path <- file.path(data_path, "cell_metadata.txt")


mini_visium <- createGiottoObject(
    expression = expr_path,
    spatial_locs = locations_path,
    cell_metadata = meta_path,
    instructions = instructions
)

# 2. process ####
# ------------ #
## filter
mini_visium <- filterGiotto(
    gobject = mini_visium,
    expression_threshold = 1,
    feat_det_in_min_cells = 1,
    min_det_feats_per_cell = 20,
    verbose = TRUE
)

mini_visium <- normalizeGiotto(
    gobject = mini_visium,
    scale_feats = FALSE,
    scale_cells = FALSE,
    verbose = TRUE
)

## add gene & cell statistics
mini_visium <- addStatistics(gobject = mini_visium)

# 3. dimension reduction ####
# ------------------------ #

## run PCA on expression values (default)
mini_visium <- runPCA(gobject = mini_visium)

# 4. save Giotto object ####
# ------------------------- #
format(object.size(mini_visium), units = "Mb")

save_location <- GiottoData:::gdata_dataset_devdir()

saveGiotto(mini_visium,
    foldername = "VisiumObject",
    dir = file.path(save_location, "Visium_multisample/"),
    overwrite = TRUE
)
