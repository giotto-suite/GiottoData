## MINI OBJECTS script for use in subobject testing ##

# 0. preparation ####
# ----------------- #
devtools::load_all(GiottoData:::gdata_devdir())
# load dataset from development directory
viz <- loadGiottoMini("vizgen")


# 1. extract subobjects ####
# ----------------- #

spat_locs <- getSpatialLocations(
    gobject = viz,
    spat_unit = "aggregate",
    name = "raw",
    output = "spatLocsObj"
)

del_net <- getSpatialNetwork(
    gobject = viz,
    spat_unit = "aggregate",
    output = "spatialNetworkObj",
    name = "Delaunay_network"
)

knn_net <- getSpatialNetwork(
    gobject = viz,
    spat_unit = "aggregate",
    output = "spatialNetworkObj",
    name = "kNN_network"
)

expr_vals_raw <- getExpression(
    gobject = viz,
    spat_unit = "aggregate",
    values = "raw",
    output = "exprObj"
)

expr_vals_norm <- getExpression(
    gobject = viz,
    spat_unit = "aggregate",
    values = "normalized",
    output = "exprObj"
)

mg_enr <- getSpatialEnrichment(
    gobject = viz,
    name = "cluster_metagene",
    spat_unit = "aggregate",
    output = "spatEnrObj"
)

gpoly <- getPolygonInfo(
    gobject = viz,
    polygon_name = "aggregate",
    return_giottoPolygon = TRUE
)

gpoints <- getFeatureInfo(
    gobject = viz,
    feat_type = "rna",
    return_giottoPoints = TRUE
)

cm <- getCellMetadata(
    gobject = viz,
    spat_unit = "aggregate",
    feat_type = "rna",
    output = "cellMetaObj"
)

fm <- getFeatureMetadata(
    gobject = viz,
    spat_unit = "aggregate",
    feat_type = "rna",
    output = "featMetaObj"
)

dim_red_umap <- getDimReduction(
    gobject = viz,
    spat_unit = "aggregate",
    feat_type = "rna",
    reduction_method = "umap",
    name = "umap",
    output = "dimObj"
)

dim_red_pca <- getDimReduction(
    gobject = viz,
    spat_unit = "aggregate",
    feat_type = "rna",
    reduction_method = "pca",
    name = "pca",
    output = "dimObj"
)

nn <- getNearestNetwork(
    gobject = viz,
    spat_unit = "aggregate",
    feat_type = "rna",
    nn_type = "sNN",
    name = "sNN.pca",
    output = "nnNetObj"
)

viz <- createSpatialGrid(
  gobject = viz,
  sdimx_stepsize = 100,
  sdimy_stepsize = 100
)

spatial_grid_obj <- getSpatialGrid(viz)

# images
# Freshly generate to allow reconnection
im_dir <- gdata_dataset_libdir("Vizgen", "Raw", "images")
DAPI_z0_image_path <- file.path(im_dir, "mini_dataset_dapi_z0.jpg")
polyT_z0_image_path <- file.path(im_dir, "mini_dataset_polyT_z0.jpg")

# x and y information from original script
ultra_mini_extent <- terra::ext(c(6400.029, 6900.037, -5150.007, -4699.967))

image_paths <- c(DAPI_z0_image_path, polyT_z0_image_path)
image_names <- c("dapi_z0", "polyT_z0")

imagelist <- createGiottoLargeImageList(
    raster_objects = image_paths,
    names = image_names,
    negative_y = TRUE,
    extent = ultra_mini_extent
)



# 2. save subobjects ####
# ----------------- #

miniobj_path <- gdata_subobject_devdir("subobjects")

# expression
expr_path <- file.path(miniobj_path, "exprObj")
saveRDS(expr_vals_raw, file = file.path(expr_path, "viz_agg_expr_raw.RDS"))
saveRDS(expr_vals_norm, file = file.path(expr_path, "viz_agg_expr_norm.RDS"))

# cell metadata
saveRDS(cm, file = file.path(miniobj_path, "cellMetaObj", "viz_agg_cellmeta.RDS"))

# feat metadata
saveRDS(fm, file = file.path(miniobj_path, "featMetaObj", "viz_agg_featmeta.RDS"))

# spatial locations
saveRDS(spat_locs, file = file.path(miniobj_path, "spatLocsObj", "viz_agg_spatlocs.RDS"))

# spatial network
sn_path <- file.path(miniobj_path, "spatialNetworkObj")
saveRDS(del_net, file = file.path(sn_path, "viz_agg_spatnet_del.RDS"))
saveRDS(knn_net, file = file.path(sn_path, "viz_agg_spatnet_knn.RDS"))

# spatial enrichment
saveRDS(mg_enr, file = file.path(miniobj_path, "spatEnrObj", "viz_agg_metagene.RDS"))

# nearest neighbor network
saveRDS(nn, file = file.path(miniobj_path, "nnNetObj", "viz_agg_sNN.RDS"))

# dim reduction
dr_path <- file.path(miniobj_path, "dimObj")
saveRDS(dim_red_pca, file = file.path(dr_path, "viz_agg_pca.RDS"))
saveRDS(dim_red_umap, file = file.path(dr_path, "viz_agg_umap.RDS"))

gpoints <- GiottoClass::wrap(gpoints)
saveRDS(gpoints, file = file.path(miniobj_path, "giottoPoints", "viz_agg_gpoints.RDS"))

gpoly <- GiottoClass::wrap(gpoly)
saveRDS(gpoly, file = file.path(miniobj_path, "giottoPolygon", "viz_agg_gpoly.RDS"))

# largeImages
# loaded by replacing a portion of the path with the end user's library path location
im_path <- file.path(miniobj_path, "giottoLargeImage")
saveRDS(imagelist[[1]], file = file.path(im_path, "viz_dapi_z0.RDS"))
saveRDS(imagelist[[2]], file = file.path(im_path, "viz_polyT_z0.RDS"))

# spatial grid
saveRDS(spatial_grid_obj, file = file.path(miniobj_path, "spatialGridObj", "viz_agg_spatialGridObj.RDS"))
