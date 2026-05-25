
## MINI VIZGEN script and dataset preparation ##

# devtools::load_all(path = '/Users/rubendries/Packages/R_Packages/Giotto/')
# devtools::load_all(path = '/Users/rubendries/r_packages/Giotto/')

library(terra)
library(GiottoClass)
library(GiottoVisuals)
library(Giotto)



# 0. preparation ####
# ----------------- #


## create instructions
instrs = createGiottoInstructions(save_dir = tempdir(),
                                  save_plot = FALSE,
                                  show_plot = TRUE,
                                  return_plot = FALSE)

## provide path to vizgen folder
data_path = system.file('/Mini_datasets/Vizgen/Raw/', package = 'GiottoData')

## 0.1 path to images ####
# ---------------------- #

# vizgen creates data from 7 z-stack slices (z0, z1, ..., z6)
## - each z-slice has a DAPI image, polyT image
## - they also have a combined composite image, created from their segmentation kit (ab stainings)
DAPI_z0_image_path = paste0(data_path, '/', 'images/mini_dataset_dapi_z0.jpg')
DAPI_z1_image_path = paste0(data_path, '/', 'images/mini_dataset_dapi_z1.jpg')

polyT_z0_image_path = paste0(data_path, '/', 'images/mini_dataset_polyT_z0.jpg')
polyT_z1_image_path = paste0(data_path, '/', 'images/mini_dataset_polyT_z1.jpg')



## 0.2 path to transcripts ####
# --------------------------- #

## each transcript has x, y and z coordinate
tx_path = paste0(data_path, '/', 'vizgen_transcripts.gz')
tx_dt = data.table::fread(tx_path)



## 0.3 path to cell boundaries folder ####
# -------------------------------------- #

## vizgen already provides segmentation information in .hdf5 files
## the hdf5 files are organized in different tiles
## Here I have already converted the hdf5 files to a simple data.table format

boundary_path = paste0(data_path, '/cell_boundaries/')

z0_polygon_DT = data.table::fread(paste0(boundary_path, '/', 'z0_polygons.gz'))
z0_polygons = createGiottoPolygonsFromDfr(name = 'z0',
                                          segmdfr = z0_polygon_DT)

z1_polygon_DT = data.table::fread(paste0(boundary_path, '/', 'z1_polygons.gz'))
z1_polygons = createGiottoPolygonsFromDfr(name = 'z1',
                                          segmdfr = z1_polygon_DT)

# 1. create subcellular dataset with transcript and polygon information ####
# ------------------------------------------------------------------------ #
vizsubc = createGiottoObjectSubcellular(gpoints = list('rna' = tx_dt[,.(global_x, -global_y, gene, global_z)]),
                                        gpolygons = list('z0' = z0_polygons, 'z1' = z1_polygons),
                                        instructions = instrs)
showGiottoFeatInfo(vizsubc)
showGiottoSpatialInfo(vizsubc)


# calculate centroid for each polygon ( = cell)
# this can/will be used when aggregating for example counts to cells
vizsubc = addSpatialCentroidLocations(
  gobject = vizsubc,
  poly_info = paste0('z',0:1),
  provenance = list('z0', 'z1'),
  return_gobject = TRUE
)
showGiottoSpatLocs(vizsubc)



# 2. add image ####
# --------------- #

# x and y information from original script
ultra_mini_extent = terra::ext(c(6400.029, 6900.037, -5150.007, -4699.967 ))

image_paths = c(DAPI_z0_image_path, DAPI_z1_image_path,
                polyT_z0_image_path, polyT_z1_image_path)
image_names = c('dapi_z0', 'dapi_z1',
                'polyT_z0', 'polyT_z1')

imagelist = createGiottoLargeImageList(raster_objects = image_paths,
                                       names = image_names,
                                       negative_y = TRUE,
                                       extent = ultra_mini_extent)

vizsubc = addGiottoImage(gobject = vizsubc,
                         largeImages = imagelist)

showGiottoImageNames(vizsubc)

# visualize
spatPlot2D(
  gobject = vizsubc,
  spat_unit = 'z0',
  show_image = T,
  largeImage_name = 'dapi_z0',
  point_shape = 'no_border',
  point_size = 2.5,
  point_alpha = 0.4,
  save_param = list(base_width = 7, base_height = 7)
)

spatPlot2D(
  gobject = vizsubc,
  spat_unit = 'z1',
  show_image = T,
  largeImage_name = 'polyT_z1',
  point_shape = 'no_border',
  point_size = 2.5,
  point_alpha = 0.4,
  save_param = list(base_width = 7, base_height = 7)
)


spatInSituPlotPoints(vizsubc,
                     feats = list('rna' = c("Htr1b", "Ackr1", "Epha7")),
                     feats_color_code = c("Htr1b" = 'green', 'Ackr1' = 'blue', 'Epha7' = 'red'),
                     show_image = TRUE,
                     largeImage_name = 'dapi_z0',
                     point_size = 0.5,
                     plot_method = 'ggplot',
                     show_polygon = TRUE,
                     use_overlap = F,
                     polygon_feat_type = 'z1',
                     polygon_color = 'yellow',
                     polygon_bg_color = 'yellow',
                     polygon_line_size = 0.2,
                     coord_fix_ratio = TRUE,
                     background_color = NA,
                     save_param = list(base_width = 7, base_height = 7))


# 3. aggregate information to matrix: polygons and transcripts ####
# --------------------------------------------------------------- #

# we will use the z1 polygon information
# we can set a global option or specify this for each command
# options('giotto.spat_unit' = 'z1') # now you don't need to think about setting spat_unit each time

# calculate z0
vizsubc = calculateOverlap(vizsubc,
                           spatial_info = 'z0',
                           feat_info = 'rna',
                           feat_subset_column = 'global_z',
                           feat_subset_ids = 0)

vizsubc = overlapToMatrix(vizsubc,
                          poly_info = 'z0',
                          feat_info = 'rna',
                          name = 'raw')

# calculate z1
vizsubc = calculateOverlap(vizsubc,
                           spatial_info = 'z1',
                           feat_info = 'rna',
                           feat_subset_column = 'global_z',
                           feat_subset_ids = 1)

vizsubc = overlapToMatrix(vizsubc,
                          poly_info = 'z1',
                          feat_info = 'rna',
                          name = 'raw')


vizsubc = aggregateStacks(gobject = vizsubc,
                          spat_units = c('z0', 'z1'),
                          feat_type = 'rna',
                          values = 'raw',
                          summarize_expression = 'sum',
                          summarize_locations = 'mean',
                          new_spat_unit = 'aggregate')

showGiottoSpatialInfo(vizsubc)
showGiottoFeatInfo(vizsubc)


# 4. filter object on aggregated layer #####
# --------------------------------------- ##
vizsubc <- filterGiotto(gobject = vizsubc,
                        spat_unit = 'aggregate',
                        expression_threshold = 1,
                        feat_det_in_min_cells = 3,
                        min_det_feats_per_cell = 5,
                        poly_info = c('aggregate'))






# 5. normalize on aggregated layer #####
# ----------------------------------- ##

# rna data, default.
# other feature modalities can be processed and filtered in an anologous manner
vizsubc <- normalizeGiotto(gobject = vizsubc, spat_unit = 'aggregate',
                           scalefactor = 5000, verbose = T)
vizsubc <- addStatistics(gobject = vizsubc, spat_unit = 'aggregate')
vizsubc <- normalizeGiotto(gobject = vizsubc, spat_unit = 'aggregate',
                           norm_methods = 'pearson_resid', update_slot = 'pearson')

spatPlot2D(gobject = vizsubc, spat_unit = 'aggregate',
           cell_color = 'total_expr', color_as_factor = F,
           largeImage_name = 'dapi_z1', show_image = TRUE,
           point_size = 3.5, point_alpha = 0.5, coord_fix_ratio = T)

spatInSituPlotPoints(vizsubc,
                     show_polygon = TRUE,
                     spat_unit = 'aggregate',
                     polygon_feat_type = 'aggregate',
                     polygon_color = 'white',
                     polygon_line_size = 0.1,
                     polygon_fill = 'total_expr',
                     polygon_fill_as_factor = F,
                     polygon_fill_gradient_style = 'sequential',
                     polygon_alpha = 1,
                     coord_fix_ratio = T)


# 6. highly variable genes ####
# ----------------------------- #

# typical way of calculating HVG
vizsubc <- calculateHVF(gobject = vizsubc, spat_unit = 'aggregate', HVFname = 'hvg_orig')

# new method based on variance of pearson residuals for each gene
vizsubc <- calculateHVF(gobject = vizsubc,
                        spat_unit = 'aggregate',
                        method = 'var_p_resid',
                        expression_values = 'pearson',
                        show_plot = T)



# 7. dimension reduction ####
# --------------------------- #

# ** 7.1 PCA ####

# we will run pca on the pre-scaled matrix from the pearson residual normalization
# if features are not specified it will automatically search for the hvf column in the feature metadata

# warning: too large a percentage of total singlular values
vizsubc <- runPCA(gobject = vizsubc,
                  spat_unit = 'aggregate',
                  expression_values = 'pearson',
                  scale_unit = F, center = F)

screePlot(vizsubc,
          ncp = 20,
          spat_unit = 'aggregate')

showGiottoDimRed(vizsubc)

plotPCA(vizsubc,
        spat_unit = 'aggregate',
        dim_reduction_name = 'pca',
        dim1_to_use = 1,
        dim2_to_use = 2)


# ** 7.2 UMAP and TSN ####
vizsubc <- runUMAP(vizsubc, dimensions_to_use = 1:8, n_threads = 4, spat_unit = 'aggregate')
plotUMAP(gobject = vizsubc, spat_unit = 'aggregate')

vizsubc <- runtSNE(vizsubc, dimensions_to_use = 1:8, spat_unit = 'aggregate')
plotTSNE(gobject = vizsubc, spat_unit = 'aggregate')


# 8. graph-based clustering ####
# ---------------------------- #
vizsubc <- createNearestNetwork(gobject = vizsubc, dimensions_to_use = 1:8, k = 10,
                                spat_unit = 'aggregate')
vizsubc <- doLeidenCluster(gobject = vizsubc, resolution = 0.05, n_iterations = 1000,
                           spat_unit = 'aggregate')
vizsubc <- doLouvainCluster(gobject = vizsubc, resolution = 5,
                           spat_unit = 'aggregate')


# visualize UMAP / TSNE cluster results
plotUMAP(gobject = vizsubc,
         spat_unit = 'aggregate',
         cell_color = 'leiden_clus',
         show_NN_network = T,
         point_size = 2.5)

spatInSituPlotPoints(vizsubc,
                     show_polygon = TRUE,
                     spat_unit = 'aggregate',
                     polygon_feat_type = 'aggregate',
                     polygon_color = 'white',
                     polygon_line_size = 0.1,
                     polygon_fill = 'leiden_clus',
                     polygon_fill_as_factor = T,
                     coord_fix_ratio = T)

plotTSNE(gobject = vizsubc,
         spat_unit = 'aggregate',
         cell_color = 'louvain_clus',
         show_NN_network = T,
         point_size = 2.5)

spatInSituPlotPoints(vizsubc,
                     show_polygon = TRUE,
                     spat_unit = 'aggregate',
                     polygon_feat_type = 'aggregate',
                     polygon_color = 'white',
                     polygon_line_size = 0.1,
                     polygon_fill = 'louvain_clus',
                     polygon_fill_as_factor = T,
                     coord_fix_ratio = T)

spatInSituPlotPoints(vizsubc,
                     spat_unit = 'aggregate',
                     show_image = T,
                     largeImage_name = 'dapi_z0',
                     feats = list('rna' = c("Htr1b", "Ackr1", "Epha7")),
                     feats_color_code = c("Htr1b" = 'green', 'Ackr1' = 'blue', 'Epha7' = 'red'),
                     point_size = 0.35,
                     show_polygon = TRUE,
                     polygon_feat_type = 'aggregate',
                     polygon_color = 'white',
                     polygon_line_size = 0.1,
                     polygon_fill = 'leiden_clus',
                     polygon_fill_as_factor = T,
                     coord_fix_ratio = TRUE)




# 9. spatial network ####
# --------------------- #
# defaults to delaunay
vizsubc = createSpatialNetwork(vizsubc, spat_unit = 'aggregate')
# kNN with k of 8 nearest
vizsubc = createSpatialNetwork(vizsubc, spat_unit = 'aggregate', method = 'kNN', k = 8)
# create spatial weight matrix
vizsubc = createSpatialWeightMatrix(vizsubc,
                                    spat_unit = 'aggregate',
                                    method = 'distance',
                                    spatial_network_to_use = 'kNN_network',
                                    return_gobject = TRUE)

pDataDT(vizsubc, 'aggregate')
spatPlot(gobject = vizsubc,
         spat_unit = 'aggregate',
         show_network = T,
         network_color = 'lightgray',
         spatial_network_name = 'Delaunay_network',
         point_size = 2.5,
         cell_color = 'leiden_clus')


## 9.1 spatial genes ####
km_spatialfeats = binSpect(vizsubc, spat_unit = 'aggregate')

spatFeatPlot2D_single(vizsubc,
               spat_unit = 'aggregate',
               expression_values = 'scaled',
               feats = km_spatialfeats[1:4]$feats,
               point_shape = 'border',
               point_border_stroke = 0.1,
               show_network = F,
               network_color = 'lightgrey',
               point_size = 2.5,
               cow_n_col = 2)

## 9.2 spatial co-expression ####
# here we use existing detectSpatialCorGenes function to calculate pairwise distances between genes
ext_spatial_genes = km_spatialfeats[1:200,]$feats
spat_cor_netw_DT = detectSpatialCorFeats(vizsubc,
                                         spat_unit = 'aggregate',
                                         method = 'network',
                                         spatial_network_name = 'Delaunay_network',
                                         subset_feats = ext_spatial_genes)

# cluster and visualize spatial co-expression genes
spat_cor_netw_DT = clusterSpatialCorFeats(spat_cor_netw_DT,
                                          name = 'spat_netw_clus',
                                          k = 5)

heatmSpatialCorFeats(vizsubc,
                     spatCorObject = spat_cor_netw_DT,
                     use_clus_name = 'spat_netw_clus',
                     heatmap_legend_param = list(title = NULL),
                     save_param = list(base_height = 6,
                                       base_width = 8,
                                       units = 'cm'))

# create and visualize metafeatures
testweight = getBalancedSpatCoexpressionFeats(spat_cor_netw_DT, rank = 'weighted', maximum = 30)

vizsubc = createMetafeats(vizsubc,
                          spat_unit = 'aggregate',
                          feat_clusters = testweight,
                          name = 'cluster_metagene')

spatCellPlot(vizsubc,
             spat_unit = 'aggregate',
             spat_enr_names = 'cluster_metagene',
             cell_annotation_values = as.character(c(1:6)),
             gradient_style = 's',
             point_size = 1.8,
             save_param = list(base_width = 15))



## 9.3 spatial structure ####
cell_proximities = cellProximityEnrichment(gobject = vizsubc,
                                           spat_unit = 'aggregate',
                                           cluster_column = 'leiden_clus',
                                           spatial_network_name = 'Delaunay_network',
                                           adjust_method = 'fdr',
                                           number_of_simulations = 2000)
## barplot
cellProximityBarplot(gobject = vizsubc,
                     CPscore = cell_proximities,
                     min_orig_ints = 5, min_sim_ints = 5)

## heatmap
cellProximityHeatmap(gobject = vizsubc,
                     CPscore = cell_proximities,
                     order_cell_types = T, scale = T,
                     color_breaks = c(-1.5, 0, 1.5),
                     color_names = c('blue', 'white', 'red'))

spatInSituPlotPoints(
  vizsubc,
  spat_unit = 'aggregate',
  show_image = T,
  largeImage_name = 'dapi_z0',
  feats = list('rna' = c("Htr1b", "Ackr1", "Epha7")),
  feats_color_code = c("Htr1b" = 'green', 'Ackr1' = 'blue', 'Epha7' = 'red'),
  point_size = 0.75,
  show_polygon = TRUE,
  polygon_feat_type = 'aggregate',
  polygon_color = 'white',
  polygon_line_size = 0.1,
  polygon_fill = 'leiden_clus',
  polygon_fill_as_factor = T,
  coord_fix_ratio = 1
)

showGiottoSpatialInfo(vizsubc)


spatInSituPlotDensity(vizsubc,
                      polygon_feat_type = 'aggregate',
                      feats = c("Htr1b", "Ackr1", "Epha7"),
                      alpha = 0.5,
                      polygon_color = 'white')

spatInSituPlotHex(vizsubc,
                  polygon_feat_type = 'aggregate',
                  feats = c("Htr1b", "Ackr1", "Epha7"))



# 10. save Giotto object ####
# ------------------------- #
format(object.size(vizsubc), units = 'Mb')

# you need to use your local GiottoData repo
giottodata_repo = './inst/Mini_datasets/'

saveGiotto(vizsubc,
           foldername = 'VizgenObject',
           #dir = paste0(system.file(package = 'GiottoData'),'/', 'Mini_datasets/Vizgen/'),
           dir = paste0(giottodata_repo, '/', 'Vizgen/'),
           overwrite = TRUE)

pDataDT(vizsubc, spat_unit = 'aggregate')



## some quick tests ##
gvizg = loadGiotto(path_to_folder = system.file('/Mini_datasets/Vizgen/VizgenObject/',
                                                package = 'GiottoData'))


# subsetting
selected_ids = pDataDT(gvizg)$cell_ID[1:100]
?activeSpatUnit
?activeFeatType

# important to specify which spatial_unit to use and which polygon information slots to update
mySubset <- subsetGiotto(gobject = gvizg,
                         cell_ids = selected_ids,
                         spat_unit = 'aggregate',
                         poly_info = c('aggregate'))

pDataDT(mySubset, 'aggregate')
fDataDT(mySubset)

spatInSituPlotPoints(mySubset,
                     spat_unit = 'aggregate',
                     show_image = T,
                     largeImage_name = 'dapi_z0',
                     feats = list('rna' = c("Htr1b", "Ackr1", "Epha7")),
                     feats_color_code = c("Htr1b" = 'green', 'Ackr1' = 'blue', 'Epha7' = 'red'),
                     point_size = 0.35,
                     show_polygon = TRUE,
                     polygon_feat_type = 'aggregate',
                     polygon_color = 'white',
                     polygon_line_size = 0.1,
                     polygon_fill = 'leiden_clus',
                     polygon_fill_as_factor = T,
                     coord_fix_ratio = TRUE)


spatPlot(gobject = mySubset, spat_unit = 'aggregate', show_network = T,
         network_color = 'lightgray', spatial_network_name = 'Delaunay_network',
         point_size = 2.5, cell_color = 'leiden_clus')

