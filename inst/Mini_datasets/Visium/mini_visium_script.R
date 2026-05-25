## MINI VISIUM script and dataset preparation ##

library(Giotto)
library(GiottoData)



# 0. preparation ####
# ----------------- #

## create instructions
instrs = createGiottoInstructions(save_dir = tempdir(),
                                  save_plot = FALSE,
                                  show_plot = TRUE,
                                  return_plot = FALSE)

## provide path to vizgen folder
data_path = system.file('/Mini_datasets/Visium/Raw/', package = 'GiottoData')

## 0.1 path to images ####
# ---------------------- #
image_path <- vector("list")
image_path["alignment"] = file.path(data_path, 'images/deg_image.png')
image_path["image"] =  file.path(data_path, 'images/deg_image2.png')

## 0.2 path to expression matrix ####
# --------------------------- #
expr_path = paste0(data_path, '/', 'visium_DG_expr.txt.gz')

## 0.3 path to spot locations ####
# -------------------------------------- #
locations_path = paste0(data_path, '/', 'visium_DG_locs.txt')

## 0.4 path to metadata ####
# -------------------------------------- #
meta_path = paste0(data_path, '/', 'visium_DG_meta.txt')

## 0.5 path to scalefactors ####
# -------------------------------------- #
scalef_path <- file.path(data_path, "scalefactors_json.json")


# 1. create visium dataset ####
# ------------------------------------------------------------------------ #
mini_visium <- createGiottoObject(expression = expr_path,
                                  spatial_locs = locations_path,
                                  cell_metadata = meta_path,
                                  instructions = instrs)

mini_visium <- addVisiumPolygons(mini_visium, scalefactor_path = scalef_path)

showGiottoSpatLocs(mini_visium)
showGiottoExpression(mini_visium)

## 1.1. add image ####
# ------------------ #

spatlocsDT = getSpatialLocations(mini_visium)
mini_extent = terra::ext(c(range(spatlocsDT$sdimx), range(spatlocsDT$sdimy)))
image_align = createGiottoLargeImage(
  raster_object = image_path$alignment,
  name = "alignment",
  extent = terra::ext(2364.5, 6522.5, -5425.25, -2620.75)
 )
image_he <- createGiottoLargeImage(
    raster_object = image_path$image,
    name = "image",
    extent = terra::ext(2000.5, 6790.5, -5730.25, -2380.75)
)
# image_he <- rescale(image_he, 13.2420382165605, 13.2287735849057)
# image_he <- spatShift(image_he, dx = 4322, dy = -3937)
imagelist <- list(image_align, image_he)
names(imagelist) <- c("alignment", "he")
mini_visium = addGiottoImage(gobject = mini_visium,
                             images = imagelist)
showGiottoImageNames(mini_visium)

## 1.2. visualize ####
# ------------------ #
spatPlot2D(gobject = mini_visium,
           spat_unit = 'cell',
           show_image = TRUE,
           image_name = 'alignment',
           point_shape = 'no_border',
           point_size = 2.5,
           point_alpha = 0.4)

spatPlot2D(gobject = mini_visium,
           spat_unit = 'cell',
           show_image = TRUE,
           image_name = 'image',
           point_shape = 'no_border',
           point_size = 2.5,
           point_alpha = 0.4)

spatInSituPlotPoints(
  mini_visium,
  show_polygon = TRUE,
  polygon_color = "cyan",
  show_image = TRUE,
  image_name = "alignment"
)


# 2 process ####
# ------------ #
mini_visium <- normalizeGiotto(gobject = mini_visium, scalefactor = 6000, verbose = T)

list_expression(mini_visium)
list_spatial_locations(mini_visium)

## filter
mini_visium <- filterGiotto(gobject = mini_visium,
                            expression_threshold = 1,
                            feat_det_in_min_cells = 5,
                            min_det_feats_per_cell = 20,
                            expression_values = c('raw'),
                            verbose = T)

## add gene & cell statistics
mini_visium <- addStatistics(gobject = mini_visium)

## visualize
spatPlot2D(gobject = mini_visium,
           show_image = TRUE,
           image_name = 'image',
           background_color = "black",
           cell_color_gradient = c("cyan", "blue", "black", "orange", "yellow"),
           point_alpha = 0.7,
           cell_color = 'nr_feats',
           color_as_factor = F)


# 3 dimension reduction ####
# ------------------------ #
mini_visium <- calculateHVF(gobject = mini_visium)

## run PCA on expression values (default)
mini_visium <- runPCA(gobject = mini_visium, feats_to_use = NULL)
screePlot(mini_visium, ncp = 30)

plotPCA(gobject = mini_visium)

## run UMAP and tSNE on PCA space (default)
mini_visium <- runUMAP(mini_visium, dimensions_to_use = 1:10)
plotUMAP(gobject = mini_visium)

mini_visium <- runtSNE(mini_visium, dimensions_to_use = 1:10)
plotTSNE(gobject = mini_visium)

# 4 cluster ####
# ------------ #

## sNN network (default)
mini_visium <- createNearestNetwork(gobject = mini_visium, dimensions_to_use = 1:5, k = 10)
## Leiden clustering
mini_visium <- doLeidenCluster(gobject = mini_visium, resolution = 0.1, n_iterations = 1000)

plotUMAP(gobject = mini_visium,
         cell_color = 'leiden_clus',
         show_NN_network = T,
         point_size = 2.5)

spatDimPlot(gobject = mini_visium,
            show_image = TRUE,
            image_name = 'image',
            cell_color = 'leiden_clus',
            dim_point_size = 2,
            spat_point_size = 2.5)


# 5. spatial network ####
# --------------------- #
mini_visium <- createSpatialNetwork(gobject = mini_visium)

mini_visium <- createSpatialNetwork(gobject = mini_visium,
                                    method = 'kNN', k = 10,
                                    maximum_distance_knn = 400,
                                    name = 'spatial_network')


# 6. spatial genes ####
# ------------------- #
showGiottoSpatNetworks(mini_visium)
ranktest <- binSpect(
    mini_visium,
    bin_method = 'rank',
    calc_hub = T,
    hub_min_int = 5,
    spatial_network_name = "Delaunay_network"
)


# 7. spatial co-expression ####
# --------------------------- #

# 7.1 cluster the top 500 spatial genes into 20 clusters
ext_spatial_genes = ranktest[1:300,]$feats

# here we use existing detectSpatialCorGenes function to calculate pairwise distances between genes (but set network_smoothing=0 to use default clustering)
spat_cor_netw_DT = detectSpatialCorFeats(mini_visium,
                                         method = 'network',
                                         spatial_network_name = 'spatial_network',
                                         subset_feats = ext_spatial_genes)

# 7.2 identify most similar spatially correlated genes for one gene
top10_genes = showSpatialCorFeats(spat_cor_netw_DT, feats = 'Dsp', show_top_feats = 10)

spatFeatPlot2D(mini_visium,
               expression_values = 'scaled',
               feats = top10_genes$variable[1:4], point_size = 3)


# 7.3 identify potenial spatial co-expression
spat_cor_netw_DT = clusterSpatialCorFeats(spat_cor_netw_DT, name = 'spat_netw_clus', k = 7)

# visualize clusters
heatmSpatialCorFeats(mini_visium,
                     spatCorObject = spat_cor_netw_DT,
                     use_clus_name = 'spat_netw_clus',
                     heatmap_legend_param = list(title = NULL),
                     save_param = list(base_height = 6, base_width = 8, units = 'cm'))


# 7.4 create metagenes / co-expression modules
cluster_genes = getBalancedSpatCoexpressionFeats(spat_cor_netw_DT, maximum = 30)
mini_visium = createMetafeats(mini_visium, feat_clusters = cluster_genes, name = 'cluster_metagene')

spatCellPlot(mini_visium,
             spat_enr_names = 'cluster_metagene',
             cell_annotation_values = as.character(c(1:7)),
             point_size = 1, cow_n_col = 3)




# 8. spatially informed clusters ####
# --------------------------------- #
my_spatial_genes = names(cluster_genes)

mini_visium <- runPCA(gobject = mini_visium,
                      feats_to_use = my_spatial_genes,
                      name = 'custom_pca')
mini_visium <- runUMAP(mini_visium,
                       dim_reduction_name = 'custom_pca',
                       dimensions_to_use = 1:20,
                       name = 'custom_umap')
mini_visium <- createNearestNetwork(gobject = mini_visium,
                                    dim_reduction_name = 'custom_pca',
                                    dimensions_to_use = 1:20, k = 5,
                                    name = 'custom_NN')
mini_visium <- doLeidenCluster(gobject = mini_visium,
                               network_name = 'custom_NN',
                               resolution = 0.15, n_iterations = 1000,
                               name = 'custom_leiden')

spatPlot2D(mini_visium,
           cell_color = 'custom_leiden')




# 9. DWLS #
# ------- #

temp <- tempdir()
getSpatialDataset(dataset = 'scRNA_mouse_brain', directory = temp)
sc_expression = paste0(temp, "/brain_sc_expression_matrix.txt.gz")
sc_metadata = paste0(temp,"/brain_sc_metadata.csv")
giotto_SC = createGiottoObject(expression = sc_expression)

# fix cell_IDs in metadata to add
sc_metadata_dt <- data.table::fread(sc_metadata)[, .SD, .SDcols = !"V1"] # ignore extra V1 col that duplicates cell_ID info
# last dash is replaced with "." character
sc_metadata_dt[, cell_ID := gsub(pattern = "(-)(?!.*-)", replacement = ".", cell_ID,  perl = T)]
# add "X" character to beginning
sc_metadata_dt[, cell_ID := paste0("X", cell_ID)]

giotto_SC = addCellMetadata(
    giotto_SC,
    new_metadata = sc_metadata_dt,
    by_column = TRUE,
    column_cell_ID = "cell_ID"
)
giotto_SC = normalizeGiotto(giotto_SC)

# keep only "Astrocytes", "Neurons", "PeripheralGlia", "Oligos" since they
# are the only ones represented strongly in this region

keep_cids <- pDataDT(giotto_SC)[Class %in% c("Astrocytes", "Neurons", "PeripheralGlia", "Oligos"), cell_ID] |> as.vector()
keep_fids <- featIDs(mini_visium)

giotto_SC_mini <- subsetGiotto(giotto_SC, cell_ids = keep_cids, feat_ids = keep_fids)

# make PAGE matrix from single cell dataset
markers_scran = findMarkers_one_vs_all(
    gobject = giotto_SC_mini,
    method = "scran",
    expression_values = "normalized",
    cluster_column = "Class",
    min_feats = 3
)

top_markers = markers_scran[, head(.SD, 10), by = "cluster"]


DWLS_matrix = Giotto::makeSignMatrixDWLSfromMatrix(
    matrix = getExpression(
        giotto_SC_mini,
        values = "normalized",
        output = "matrix"
    ),
    cell_type_vector = pDataDT(giotto_SC_mini)$Class,
    sign_gene = top_markers$feats
)

mini_visium <- runDWLSDeconv(gobject = mini_visium,
                              sign_matrix = DWLS_matrix)


# Plot DWLS deconvolution result with Pie plots
spatDeconvPlot(mini_visium,
               show_image = T,
               radius = 50,
               save_param = list(save_name = "spat_DWLS_pie_plot"))



# 10. save Giotto object ####
# ------------------------- #
format(object.size(mini_visium), units = 'Mb')

save_location <- GiottoData:::gdata_dataset_devdir()

saveGiotto(mini_visium,
           foldername = 'VisiumObject',
           dir = paste0(save_location, '/', 'Visium/'),
           overwrite = TRUE)

pDataDT(mini_visium)


## some quick tests ##
visium_test = loadGiotto(path_to_folder = system.file('/Mini_datasets/Visium/VisiumObject/',
                                                      package = 'GiottoData'))


spatPlot2D(visium_test,
           show_image = T,
           image_name = 'image',
           cell_color = 'custom_leiden')

spatDimPlot(gobject = visium_test,
            show_image = TRUE,
            image_name = 'image',
            cell_color = 'leiden_clus',
            dim_point_size = 2,
            spat_point_size = 2.5)


#
# # 10. build from scratch ####
# # -------------------------- #
#
#
# # 10.1 get expression data as matrix
# list_expression(mini_visium)
# raw_matrix = getExpression(mini_visium, values = 'raw', output = 'matrix')
# normalized_matrix = getExpression(mini_visium, values = 'normalized', output = 'matrix')
# scaled_matrix = getExpression(mini_visium, values = 'scaled', output = 'matrix')
#
# # 10.2 get spatial location data as a 3-column data.table
# list_spatial_locations(mini_visium)
# spatial_locations = getSpatialLocations(mini_visium, name = 'raw', output = 'data.table')
#
# # 10.3 get cell and feature metadata as data.tables
# list_cell_metadata(mini_visium)
# cell_metadata = getCellMetadata(mini_visium, output = 'data.table')
# list_feat_metadata(mini_visium)
# feat_metadata = getFeatureMetadata(mini_visium, output = 'data.table')
#
#
# # 10.4 dimension reduction as matrix
# list_dim_reductions(mini_visium)
# pca_dim = getDimReduction(mini_visium, reduction_method = 'pca', name = 'pca', output = 'matrix')
# umap_dim = getDimReduction(mini_visium, reduction_method = 'umap', name = 'umap', output = 'matrix')
# tsne_dim = getDimReduction(mini_visium, reduction_method = 'tsne', name = 'tsne', output = 'matrix')
#
# # 10.5 get nearest networks as data.table
# list_nearest_networks(mini_visium)
# sNN_network = getNearestNetwork(mini_visium, nn_type = 'sNN', name = 'sNN.pca', output = 'data.table')
# sNN_network = sNN_network[,.(from, to, distance)]
#
# # 10.6 large images
# list_images(mini_visium)
# images = getGiottoImage(mini_visium, image_type = 'largeImage', name = 'image')
# plot(images)
#
#
# ## 10.1 create spatialExperiment ####
#
# speg = giottoToSpatialExperiment(giottoObj = mini_visium)
#
# class(speg[[1]])
#
# speg_rna = speg[[1]]
#
# SummarizedExperiment::assayNames(speg_rna)
#
# speg_rna@NAMES
#
# speg_rna@assays@data$normalized_rna_cell
#
#
#
# ?SpatialExperiment::SpatialExperiment()
#
# # remake
# mini_visium_remake <- createGiottoObject(expression = list('cell' =
#                                                              list('rna' =
#                                                                     list('raw' = raw_matrix,
#                                                                          'normalized' = normalized_matrix,
#                                                                          'scaled' = scaled_matrix))),
#                                          spatial_locs = list('cell' =
#                                                                list('raw' = spatial_locations)),
#                                          instructions = instrs)
#
#
#
# # remake
# mini_visium_remake <- createGiottoObject(expression = list('cell' =
#                                                              list('rna' =
#                                                                     list('raw' = raw_matrix,
#                                                                          'normalized' = normalized_matrix,
#                                                                          'scaled' = scaled_matrix))),
#                                          instructions = instrs)
#
#
# # option 1: create S4 object + set function
# # option 2: read alternative input --> S4 function + set function
# # option 3: createGiottoObject using #1 or #2
#
# mini_visium_remake = setSpatialLocations(gobject = mini_visium_remake, spatlocs = spatial_locations)
#
# mini_visium_remake = set_cell_metadata(gobject = mini_visium_remake,
#                                        metadata = cell_metadata,
#                                        spat_unit = 'cell', feat_type = 'rna')
#
# mini_visium_remake = set_feature_metadata(gobject = mini_visium_remake,
#                                        metadata = feat_metadata,
#                                        spat_unit = 'cell', feat_type = 'rna')
#
# pca_obj = create_dim_obj(name = 'pca', reduction = 'cells', reduction_method = 'pca',
#                          coordinates = pca_dim)
# umap_obj = create_dim_obj(name = 'umap', reduction = 'cells', reduction_method = 'umap',
#                          coordinates = umap_dim)
# tsne_obj = create_dim_obj(name = 'tsne', reduction = 'cells', reduction_method = 'tsne',
#                          coordinates = tsne_dim)
# mini_visium_remake = setDimReduction(gobject = mini_visium_remake, dimObject = pca_obj)
# mini_visium_remake = setDimReduction(gobject = mini_visium_remake, dimObject = umap_obj)
# mini_visium_remake = setDimReduction(gobject = mini_visium_remake, dimObject = tsne_obj)
#
# mini_visium_remake = setNearestNetwork(gobject = mini_visium_remake, nn_network = sNN_network)
#
# spatDimPlot(gobject = mini_visium_remake,
#             show_NN_network = T,
#             show_image = F,
#             largeImage_name = 'image',
#             cell_color = 'leiden_clus',
#             dim_point_size = 2, spat_point_size = 2.5)
#
# str(mini_visium, 2)
#
#


