## MINI CosMx script and dataset preparation ##


library(Giotto) # devtools::load_all(path = '/Users/rubendries/Packages/R_Packages/Giotto/')
library(GiottoData) # devtools::load_all(path = '/Users/rubendries/Packages/R_Packages/GiottoData/')

library(terra)
library(data.table)



# 0. preparation ####
# ----------------- #

## create instructions
instrs = createGiottoInstructions(save_dir = tempdir(),
                                  save_plot = FALSE,
                                  show_plot = TRUE,
                                  return_plot = FALSE)

## provide path to vizgen folder
mini_data_path = system.file('/Mini_datasets/CosMx/Raw/', package = 'GiottoData')


# 1 . load transcript coordinates ####
# ---------------------------------- #
tx_coord_all = data.table::fread(paste0(mini_data_path, '/', 'Lung12_tx_file.csv'))
tx_coord_all[, table(z)]
tx_coord_all[, table(CellComp)]

# split probe IDS
all_IDs = tx_coord_all[, unique(target)]

# negative probe IDs
neg_IDs = all_IDs[grepl(pattern = 'NegPrb', all_IDs)]
feat_IDs = all_IDs[!all_IDs %in% neg_IDs]

# split detections
feat_coords_all = tx_coord_all[target %in% feat_IDs]
neg_coords_all = tx_coord_all[target %in% neg_IDs]

neg_points = createGiottoPoints(
  x = neg_coords_all[, .(target, x_global_px, y_global_px)]
)
plot(neg_points, point_size = 2, feats = neg_IDs)

# 2. load field of vision (fov) positions ####
# ------------------------------------------ #
fov_offset_file = data.table::fread(paste0(mini_data_path, '/', 'Lung12_fov_positions_file.csv'))



# 3. create giotto objects for individual FOVs ####
# ----------------------------------------------- #
gobjects_list = list()
id_set = c('02', '03')

for(fov_i in 1:length(id_set)) {

  fov_id = id_set[fov_i]


  # 1. original composite image as png
  original_composite_image = paste0(mini_data_path, '/', 'CellComposite/CellComposite_F0', fov_id,'.jpg')

  # 2. input cell segmentation as mask file
  segmentation_mask = paste0(mini_data_path, '/', 'CellLabels/CellLabels_F0', fov_id, '.tif')

  # 3. input features coordinates + offset
  feat_coord = feat_coords_all[fov == as.numeric(fov_id)]
  neg_coord = neg_coords_all[fov == as.numeric(fov_id)]
  feat_coord = feat_coord[,.(x_local_px, y_local_px, z, target)]
  neg_coord = neg_coord[,.(x_local_px, y_local_px, z, target)]
  colnames(feat_coord) = c('x', 'y', 'z', 'gene_id')
  colnames(neg_coord) = c('x', 'y', 'z', 'gene_id')
  feat_coord = feat_coord[,.(x, y, gene_id)]
  neg_coord = neg_coord[,.(x, y, gene_id)]


  fovsubset = createGiottoObjectSubcellular(
    gpoints = list('rna' = feat_coord,
                   'neg_probe' = neg_coord),
    gpolygons = list('cell' = segmentation_mask),
    polygon_mask_list_params = list(
      remove_background_polygon = TRUE,
      remove_unvalid_polygons = TRUE,
      mask_method = 'guess',
      flip_vertical = FALSE,
      flip_horizontal = FALSE,
      shift_horizontal_step = FALSE,
      shift_vertical_step = FALSE
    ),
    instructions = instrs
  )


  # cell centroids are now used to provide the spatial locations
  fovsubset = addSpatialCentroidLocations(fovsubset,
                                          poly_info = 'cell')

  # save extent to update images
  extent = terra::ext(fovsubset@spatial_info$cell@spatVector)

  # create and add Giotto images
  composite = createGiottoLargeImage(raster_object = original_composite_image,
                                     negative_y = FALSE,
                                     extent = extent,
                                     name = 'composite')

  fovsubset = addGiottoImage(gobject = fovsubset,
                             images = list(composite))

  gobjects_list[[fov_i]] = fovsubset

}


new_names = paste0("fov0", id_set)

id_match = match(as.numeric(id_set), fov_offset_file$fov)
x_shifts = fov_offset_file[id_match]$x_global_px
y_shifts = fov_offset_file[id_match]$y_global_px


# 3. join giotto FOV objects ####
# ----------------------------- #

# Create Giotto object that includes all selected FOVs
fov_join = joinGiottoObjects(gobject_list = gobjects_list,
                             gobject_names = new_names,
                             join_method = 'shift',
                             x_shift = x_shifts,
                             y_shift = y_shifts)

# Set up vector of image names
id_set = c('02', '03')
new_names = paste0("fov0", id_set)
image_names = paste0(new_names, '-composite')

showGiottoImageNames(fov_join)


rna_ids = fov_join@feat_ID$rna[1:75]

spatInSituPlotPoints(fov_join,
                     show_image = TRUE,
                     image_name = image_names,
                     feats = list('rna' = c(rna_ids)),
                     show_legend = F,
                     spat_unit = 'cell',
                     point_size = 0.75,
                     show_polygon = TRUE,
                     use_overlap = FALSE,
                     polygon_feat_type = 'cell',
                     polygon_color = 'white',
                     polygon_line_size = 0.3)

showGiottoImageNames(fov_join)


spatPlot2D(gobject = fov_join,
           show_image = TRUE,
           image_name = c('fov002-composite', 'fov003-composite'),
           point_shape = 'no_border',
           point_size = 2.5,
           point_alpha = 0.5,
           coord_fix_ratio = 1)


# 4. create aggregation matrices ####
# --------------------------------- #

# Find the feature points overlapped by polygons. This overlap information is then
# returned to the relevant giottoPolygon object's overlaps slot.
fov_join = calculateOverlapRaster(fov_join, feat_info = 'rna')
fov_join = calculateOverlapRaster(fov_join, feat_info = 'neg_probe')

# Convert the overlap information into a cell by feature expression matrix which
# is then stored in the Giotto object's expression slot
fov_join = overlapToMatrix(fov_join, feat_info = 'rna')
fov_join = overlapToMatrix(fov_join, feat_info = 'neg_probe')

showGiottoExpression(fov_join)



# 5. check distributions ####
# ------------------------- #
filterDistributions(fov_join,
                    plot_type = 'hist',
                    detection = 'cells',
                    method = 'sum',
                    feat_type = 'rna',
                    nr_bins = 30)

filterDistributions(fov_join,
                    plot_type = 'hist',
                    detection = 'cells',
                    method = 'sum',
                    feat_type = 'neg_probe',
                    nr_bins = 25)


spatInSituPlotDensity(gobject = fov_join,
                      feats = c("MMP2", "VEGFA", "IGF1R",
                                'MKI67', 'EPCAM', 'KRT8'),
                      cow_n_col = 2)

spatInSituPlotPoints(fov_join,
                     show_image = F,
                     largeImage_name = image_names,
                     feats = list('rna' = c("MMP2", "VEGFA", "IGF1R",
                                            'MKI67', 'EPCAM', 'KRT8')),
                     show_legend = TRUE,
                     spat_unit = 'cell',
                     point_size = 1.75,
                     show_polygon = TRUE,
                     use_overlap = FALSE,
                     polygon_feat_type = 'cell',
                     polygon_color = 'white',
                     polygon_line_size = 0.3)

# combine cell data
morphometa = combineCellData(fov_join,
                             feat_type = 'rna')

# combine feature data
featmeta = combineFeatureData(fov_join,
                              feat_type = c('rna'))

# combine overlapping feature data
featoverlapmeta = combineFeatureOverlapData(fov_join,
                                            feat_type = c('rna'))



# 6. normalization ####
# ------------------- #

# filter (feat_type = 'rna' by default)
fov_join <- filterGiotto(gobject = fov_join,
                         feat_type = 'rna',
                         expression_threshold = 1,
                         feat_det_in_min_cells = 3,
                         min_det_feats_per_cell = 5)

# normalize
# standard method of normalization (log normalization based)
fov_join <- normalizeGiotto(gobject = fov_join,
                            feat_type = 'rna',
                            norm_methods = 'standard',
                            verbose = TRUE)
fov_join <- normalizeGiotto(gobject = fov_join,
                            feat_type = 'neg_probe',
                            norm_methods = 'standard',
                            library_size_norm = FALSE,
                            verbose = TRUE)

# new normalization method based on pearson correlations (Lause/Kobak et al. 2021)
# this normalized matrix is given the name 'pearson' using the update_slot param
fov_join <- normalizeGiotto(gobject = fov_join,
                            feat_type = 'rna',
                            scalefactor = 5000,
                            verbose = TRUE,
                            norm_methods = 'pearson_resid',
                            update_slot = 'pearson')

showGiottoExpression(fov_join)


# add statistics based on log normalized values for features rna and negative probes
fov_join = addStatistics(gobject = fov_join,
                         expression_values = 'raw',
                         feat_type = 'rna')
fov_join = addStatistics(gobject = fov_join,
                         expression_values = 'raw',
                         feat_type = 'neg_probe')

# View cellular data (default is feat = 'rna')
showGiottoCellMetadata(fov_join)
# View feature data
showGiottoFeatMetadata(fov_join)




cell_meta = pDataDT(fov_join)

cell_area = terra::expanse(fov_join@spatial_info$cell@spatVector)
fov_join@spatial_info$cell@spatVector[['cell_area']] = cell_area

perimeter = terra::perim(fov_join@spatial_info$cell@spatVector)
fov_join@spatial_info$cell@spatVector[['perimeter']] = perimeter

spatvecDT <- getPolygonInfo(
    fov_join, polygon_name = "cell", return_giottoPolygon = TRUE
) %>% data.table::as.data.table(geom = "XY")



spatvecDT = unique(spatvecDT[,.(poly_ID, cell_area, perimeter)])

cell_meta = data.table::merge.data.table(
    cell_meta, spatvecDT, by.x = 'cell_ID', by.y = 'poly_ID'
)

plot(cell_meta$cell_area, cell_meta$perimeter)

plot(cell_meta$total_expr, cell_meta$perimeter)

plot(cell_meta$total_expr, cell_meta$area)

plot(cell_meta$nr_feats, cell_meta$area)




# 6. visualize transcripts ####
# --------------------------- #
segmDT <- getPolygonInfo(
    fov_join, polygon_name = "cell", return_giottoPolygon = TRUE) %>%
    data.table::as.data.table(geom = "XY")

geomDT <- getPolygonInfo(
    fov_join, polygon_name = "cell", polygon_overlap = "rna") %>%
    data.table::as.data.table(geom = "XY")
geomDT[, inside := ifelse(is.na(poly_ID), 'N', 'Y')]
geomDT[, cell_inside := ifelse(is.na(poly_ID), 'N', poly_ID)]

library(ggplot2)

distinct_colors = getDistinctColors(n = length(unique(geomDT$cell_inside)))

color_code = c('red', distinct_colors)
names(color_code) = c('N', unique(geomDT$cell_inside))

pl = ggplot()
pl = pl + geom_point(data = geomDT, aes(x = x, y = y, color = cell_inside, size = inside, shape = inside), show.legend = F)
pl = pl + scale_color_manual(values = color_code)
pl = pl + scale_size_manual(values = c('N' = 0.7, 'Y' = 0.3))
pl = pl + theme_minimal() + theme(panel.background = element_rect(fill="black"), panel.grid = element_blank())
pl = pl + geom_polygon(data = segmDT, aes(x = x, y = y, group = poly_ID), color = 'white', linewidth = 0.2)
pl


pl = ggplot()
pl = pl + geom_point(data = geomDT, aes(x = x, y = y, color = cell_inside, size = inside, shape = inside), show.legend = F)
pl = pl + scale_color_manual(values = color_code)
pl = pl + scale_size_manual(values = c('N' = 0.7, 'Y' = 0.3))
pl = pl + theme_minimal() + theme(panel.background = element_rect(fill="black"), panel.grid = element_blank())
pl = pl + geom_polygon(data = segmDT, aes(x = x, y = y, group = poly_ID), color = 'white', size = 0.2, fill = NA)
pl


# 7.




# 10. save Giotto object ####
# ------------------------- #
format(object.size(fov_join), units = 'Mb')

# you need to use your local GiottoData repo if you used library(GiottoData), rather than devtools::load_all()
giottodata_repo = '/Users/rubendries/Packages/R_Packages/GiottoData/inst/Mini_datasets/'

saveGiotto(fov_join,
           foldername = 'CosMxObject',
           #dir = paste0(system.file(package = 'GiottoData'),'/', 'Mini_datasets/'),
           dir = paste0(giottodata_repo, '/', 'CosMx/'),
           overwrite = TRUE)


## some quick tests ##
fov_join_reload = loadGiotto(path_to_folder = system.file('/Mini_datasets/CosMx/CosMxObject/',
                                                          package = 'GiottoData'))

showGiottoImageNames(fov_join_reload)

fov_join_reload@images

rna_ids = fov_join_reload@feat_ID$rna[1:75]

spatInSituPlotPoints(fov_join_reload,
                     show_image = TRUE,
                     image_name = image_names,
                     feats = list('rna' = c(rna_ids)),
                     show_legend = F,
                     spat_unit = 'cell',
                     point_size = 0.75,
                     show_polygon = TRUE,
                     use_overlap = FALSE,
                     polygon_feat_type = 'cell',
                     polygon_color = 'white',
                     polygon_line_size = 0.3)



