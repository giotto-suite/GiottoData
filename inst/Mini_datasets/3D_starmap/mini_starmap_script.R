
library(Giotto)

options(giotto.color_cd_pal = "Spectral")
options(giotto.color_c_rev = TRUE)

datadir <- "inst/Mini_datasets/3D_starmap/"
loc_path <- file.path(datadir, "starmap_cell_loc.txt")
expr_path <- file.path(datadir, "starmap_expr.txt.gz")

starmap_mini <- createGiottoObject(
    expression = expr_path,
    spatial_locs = loc_path,
)

filterDistributions(starmap_mini, detection = 'feats')

filterDistributions(starmap_mini, detection = 'cells')

filterCombinations(
    starmap_mini,
    expression_thresholds = c(1),
    feat_det_in_min_cells = c(50, 100, 200),
    min_det_feats_per_cell = c(20, 28, 28)
)

starmap_mini <- filterGiotto(
    gobject = starmap_mini,
    expression_threshold = 1,
    feat_det_in_min_cells = 50,
    min_det_feats_per_cell = 20,
    expression_values = c('raw'),
    verbose = TRUE
)

starmap_mini <- normalizeGiotto(
    gobject = starmap_mini,
    scalefactor = 6000,
    verbose = TRUE
)

starmap_mini <- addStatistics(gobject = starmap_mini)

starmap_mini <- runPCA(gobject = starmap_mini, method = 'factominer')

screePlot(starmap_mini, ncp = 30)
plotPCA(gobject = starmap_mini)

# 2D umap
starmap_mini <- runUMAP(starmap_mini, dimensions_to_use = 1:8)
plotUMAP(gobject = starmap_mini)

# 3D umap
starmap_mini <- runUMAP(
    starmap_mini,
    dimensions_to_use = 1:8,
    name = '3D_umap',
    n_components = 3
)
plotUMAP_3D(gobject = starmap_mini, dim_reduction_name = '3D_umap')

# 2D tsne
starmap_mini <- runtSNE(starmap_mini, dimensions_to_use = 1:8)
plotTSNE(gobject = starmap_mini)

# 3D tsne
starmap_mini <- runtSNE(starmap_mini, dimensions_to_use = 1:8, dims = 3)
plotTSNE_3D(gobject = starmap_mini)

# clustering
starmap_mini <- createNearestNetwork(gobject = starmap_mini, 
                                     dimensions_to_use = 1:8, 
                                     k = 25)
starmap_mini <- doLeidenCluster(gobject = starmap_mini, 
                                resolution = 0.5, 
                                n_iterations = 1000)

# 2D umap
plotUMAP(
    gobject = starmap_mini,
    cell_color = 'leiden_clus',
    show_NN_network = TRUE,
    point_size = 2.5
)

# 3D umap
plotUMAP_3D(gobject = starmap_mini, 
            dim_reduction_name = '3D_umap',
            cell_color = 'leiden_clus')

# 2D umap + coordinates
spatDimPlot(gobject = starmap_mini, 
            cell_color = 'leiden_clus',
            dim_point_size = 2, 
            spat_point_size = 2.5)

# 3D umap + coordinates
# spatDimPlot3D(gobject = starmap_mini,
#               cell_color = 'leiden_clus', dim_reduction_name = '3D_umap')


# heatmap and dendrogram
showClusterHeatmap(gobject = starmap_mini, cluster_column = 'leiden_clus')

showClusterDendrogram(starmap_mini, h = 0.5, rotate = TRUE,
                      cluster_column = 'leiden_clus')

gini_markers = findMarkers_one_vs_all(
    gobject = starmap_mini,
    method = 'gini',
    expression_values = 'normalized',
    cluster_column = 'leiden_clus',
    min_feats = 20,
    min_expr_gini_score = 0.5,
    min_det_gini_score = 0.5
)

# get top 2 genes per cluster and visualize with violinplot
topgenes_gini = gini_markers[, head(.SD, 2), by = 'cluster']
violinPlot(starmap_mini, feats = topgenes_gini$feats,
           cluster_column = 'leiden_clus')

# get top 6 genes per cluster and visualize with heatmap
topgenes_gini2 = gini_markers[, head(.SD, 6), by = 'cluster']
plotMetaDataHeatmap(starmap_mini, selected_feats = topgenes_gini2$feats,
                    metadata_cols = c('leiden_clus'))

# cell type annotation
clusters_cell_types = c('cell A', 'cell B', 'cell C', 'cell D',
                        'cell E', 'cell F', 'cell G', 'cell H')
names(clusters_cell_types) = 1:8
starmap_mini = annotateGiotto(gobject = starmap_mini,
                              annotation_vector = clusters_cell_types,
                              cluster_column = 'leiden_clus',
                              name = 'cell_types')
# check new cell metadata
pDataDT(starmap_mini)

# visualize annotations
spatDimPlot(gobject = starmap_mini, cell_color = 'cell_types',
            spat_point_size = 2, dim_point_size = 2)

dimFeatPlot3D(starmap_mini,
              dim_reduction_name = '3D_umap',
              expression_values = 'scaled',
              genes = "Pcp4",
              genes_high_color = 'red', 
              genes_mid_color = 'white', 
              genes_low_color = 'darkblue')

spatFeatPlot3D(starmap_mini,
               expression_values = 'scaled',
               feats = "Pcp4",
               show_other_cells = FALSE,
               genes_high_color = 'red', 
               genes_mid_color = 'white', 
               genes_low_color = 'darkblue')

spatFeatPlot3D(starmap_mini,
               expression_values = 'scaled',
               feats = "Pcp4",
               show_other_cells = FALSE, 
               axis_scale = "real",
               genes_high_color = 'red', 
               genes_mid_color = 'white', 
               genes_low_color = 'darkblue')

# spatial grid
starmap_mini <- createSpatialGrid(gobject = starmap_mini,
                                  sdimx_stepsize = 200,
                                  sdimy_stepsize = 200,
                                  sdimz_stepsize = 20,
                                  minimum_padding = 10)
showGiottoSpatGrids(starmap_mini)

# visualize grid
spatPlot2D(gobject = starmap_mini, show_grid = TRUE, point_size = 1.5)

# spatial network
plotStatDelaunayNetwork(gobject = starmap_mini, maximum_distance = 200,
                        method = 'delaunayn_geometry')

starmap_mini = createSpatialNetwork(gobject = starmap_mini, 
                                    minimum_k = 2,
                                    maximum_distance_delaunay = 200,
                                    method = 'Delaunay',
                                    delaunay_method = 'delaunayn_geometry')

starmap_mini = createSpatialNetwork(gobject = starmap_mini, 
                                    minimum_k = 2,
                                    method = 'kNN', 
                                    k = 10)
showGiottoSpatNetworks(starmap_mini)

# visualize the two different spatial networks
spatPlot(gobject = starmap_mini, 
         show_network = TRUE,
         network_color = 'gray', 
         network_alpha = 0.3,
         spatial_network_name = 'Delaunay_network',
         point_size = 1.5, 
         cell_color = 'leiden_clus',
         background_color = "black")

spatPlot(gobject = starmap_mini, 
         show_network = TRUE,
         network_color = 'gray', 
         network_alpha = 0.3,
         spatial_network_name = 'kNN_network',
         point_size = 1.5, 
         cell_color = 'leiden_clus',
         background_color = "black")

km_spatialgenes = binSpect(starmap_mini)
spatFeatPlot2D(starmap_mini, 
               expression_values = 'scaled',
               feats = km_spatialgenes[1:4]$feats,
               point_shape = 'border', 
               point_border_stroke = 0.1,
               show_network = FALSE, 
               network_color = 'lightgrey',
               point_size = 1.5)

rank_spatialgenes = binSpect(starmap_mini, bin_method = 'rank')
spatFeatPlot2D(starmap_mini, 
               expression_values = 'scaled',
               feats = rank_spatialgenes[1:4]$feats,
               point_shape = 'border', 
               point_border_stroke = 0.1,
               show_network = FALSE, 
               network_color = 'lightgrey', 
               point_size = 1.5)

silh_spatialgenes = silhouetteRank(gobject = starmap_mini) # TODO: suppress print output
spatFeatPlot2D(starmap_mini, 
               expression_values = 'scaled',
               feats = silh_spatialgenes[1:4]$genes, # TODO update to use feats
               point_shape = 'border', 
               point_border_stroke = 0.1,
               show_network = FALSE, 
               network_color = 'lightgrey', 
               point_size = 2.5)

# coexpression

# 1. calculate spatial correlation scores
ext_spatial_genes = km_spatialgenes[1:20]$feats
spat_cor_netw_DT = detectSpatialCorFeats(starmap_mini,
                                         method = 'network',
                                         spatial_network_name = 'Delaunay_network',
                                         subset_feats = ext_spatial_genes)

# 2. cluster correlation scores
spat_cor_netw_DT = clusterSpatialCorFeats(spat_cor_netw_DT,
                                          name = 'spat_netw_clus', 
                                          k = 6)
heatmSpatialCorGenes(starmap_mini, 
                     spatCorObject = spat_cor_netw_DT,
                     use_clus_name = 'spat_netw_clus')

netw_ranks = rankSpatialCorGroups(starmap_mini,
                                  spatCorObject = spat_cor_netw_DT,
                                  use_clus_name = 'spat_netw_clus')

# TODO show function, but it is mainly used for its returns....
top_netw_spat_cluster = showSpatialCorFeats(spat_cor_netw_DT,
                                            use_clus_name = 'spat_netw_clus',
                                            selected_clusters = 6,
                                            show_top_feats = 1)

cluster_genes_DT = showSpatialCorFeats(spat_cor_netw_DT,
                                       use_clus_name = 'spat_netw_clus',
                                       show_top_feats = 1)
cluster_genes = cluster_genes_DT$clus; names(cluster_genes) = cluster_genes_DT$feat_ID


starmap_mini = createMetafeats(starmap_mini,
                               feat_clusters = cluster_genes,
                               name = 'cluster_metagene')
spatCellPlot(starmap_mini,
             spat_enr_names = 'cluster_metagene',
             cell_annotation_values = netw_ranks$clusters,
             point_size = 1.5, cow_n_col = 3)

# HMRF
hmrf_folder = file.path(tempdir(), '11_HMRF/')
if(!file.exists(hmrf_folder)) dir.create(hmrf_folder, recursive = TRUE)

# perform hmrf
my_spatial_genes = km_spatialgenes[1:20]$feats
HMRF_spatial_genes = doHMRF(
    gobject = starmap_mini,
    expression_values = 'scaled',
    spatial_genes = my_spatial_genes,
    spatial_network_name = 'Delaunay_network',
    k = 6,
    betas = c(10,2,2),
    output_folder = file.path(hmrf_folder, 'Spatial_genes/SG_top20_k6_scaled')
)

# check and select hmrf
for(i in seq(10, 14, by = 2)) {
    viewHMRFresults2D(gobject = starmap_mini,
                      HMRFoutput = HMRF_spatial_genes,
                      k = 6, 
                      betas_to_view = i,
                      point_size = 2)
}

for(i in seq(10, 14, by = 2)) {
    viewHMRFresults3D(gobject = starmap_mini,
                      HMRFoutput = HMRF_spatial_genes,
                      k = 6, betas_to_view = i,
                      point_size = 2)
}

starmap_mini = addHMRF(gobject = starmap_mini,
                       HMRFoutput = HMRF_spatial_genes,
                       k = 6, 
                       betas_to_add = c(12),
                       hmrf_name = 'HMRF')

# visualize selected hmrf result
giotto_colors = getDistinctColors(6)
names(giotto_colors) = 1:6
spatPlot(gobject = starmap_mini, 
         cell_color = 'HMRF_k6_b.12',
         point_size = 3, 
         coord_fix_ratio = 1, 
         cell_color_code = giotto_colors)

# cell neighborhood
set.seed(seed = 2841)
cell_proximities = cellProximityEnrichment(
    gobject = starmap_mini,
    cluster_column = 'cell_types',
    spatial_network_name = 'Delaunay_network',
    adjust_method = 'fdr',
    number_of_simulations = 1000)

# barplot
cellProximityBarplot(gobject = starmap_mini,
                     CPscore = cell_proximities,
                     min_orig_ints = 2, 
                     min_sim_ints = 2, 
                     p_val = 0.5)

## heatmap
cellProximityHeatmap(gobject = starmap_mini, 
                     CPscore = cell_proximities,
                     order_cell_types = TRUE, 
                     scale = TRUE,
                     color_breaks = c(-1.5, 0, 1.5),
                     color_names = c('blue', 'white', 'red'))

# network
cellProximityNetwork(gobject = starmap_mini, 
                     CPscore = cell_proximities,
                     remove_self_edges = TRUE, 
                     only_show_enrichment_edges = TRUE)

# network with self-edges
cellProximityNetwork(gobject = starmap_mini, 
                     CPscore = cell_proximities,
                     remove_self_edges = FALSE, 
                     self_loop_strength = 0.3,
                     only_show_enrichment_edges = FALSE,
                     rescale_edge_weights = TRUE,
                     node_size = 8,
                     edge_weight_range_depletion = c(1, 2),
                     edge_weight_range_enrichment = c(2,5))

# visualize specific cell types
pDataDT(starmap_mini)

# Option 1
spec_interaction = "cell D--cell H" # needs to be in alphabetic order! first D, then H
cellProximitySpatPlot2D(gobject = starmap_mini,
                        interaction_name = spec_interaction,
                        show_network = TRUE,
                        cluster_column = 'cell_types',
                        cell_color = 'cell_types',
                        cell_color_code = c('cell H' = 'lightblue', 'cell D' = 'red'),
                        point_size_select = 4, 
                        point_size_other = 2)

# Option 2: create additional metadata
starmap_mini = addCellIntMetadata(starmap_mini,
                                  spatial_network = 'Delaunay_network',
                                  cluster_column = 'cell_types',
                                  cell_interaction = spec_interaction,
                                  name = 'D_H_interactions')
spatPlot(starmap_mini, 
         cell_color = 'D_H_interactions', 
         legend_symbol_size = 3,
         select_cell_groups =  c('other_cell D', 'other_cell H', 'select_cell D', 'select_cell H'))

# cross sections

# create cross section
starmap_mini = createCrossSection(starmap_mini,
                                  method="equation",
                                  equation=c(0,1,0,600),
                                  extend_ratio = 0.6)

# show cross section
insertCrossSectionSpatPlot3D(starmap_mini, 
                             cell_color = 'leiden_clus',
                             axis_scale = 'cube',
                             point_size = 2)

# for cell annotation
crossSectionPlot(starmap_mini,
                 point_size = 2, 
                 point_shape = "border",
                 cell_color = "leiden_clus")

crossSectionFeatPlot3D(
    starmap_mini,
    point_size = 2,
    feats = c("Slc17a7"),
    expression_values = 'scaled',
    axis_scale = "cube"
)


# 10. save Giotto object ####
# ------------------------- #
format(object.size(starmap_mini), units = 'Mb')

# you need to use your local GiottoData repo if you used library(GiottoData), rather than devtools::load_all()
giottodata_repo = '/inst/Mini_datasets/'

saveGiotto(starmap_mini,
           foldername = '3DStarmapObject',
           dir = paste0(getwd(), giottodata_repo, '3D_starmap/'),
           overwrite = TRUE)



