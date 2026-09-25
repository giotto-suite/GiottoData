# The saved subobjects are serialized snapshots that can predate slot layout
# changes in GiottoClass. loadSubObjectMini() runs initialize() so that what a
# caller gets back matches the installed class definition. These tests guard
# that: a mini whose file is older than a migration must still load with the
# current slots, not the ones it was written with.

avail <- GiottoData:::list_subobject_mini()

test_that("every subobject type is loadable", {
    skip_if_not(nrow(avail) > 0L, "no subobject minis installed")

    for (i in seq_len(nrow(avail))) {
        type <- avail$type[[i]]
        idx <- avail$index[[i]]
        obj <- loadSubObjectMini(type, idx = idx)
        expect_s4_class(obj, type)
        expect_true(validObject(obj))
    }
})

test_that("loaded subobjects carry the installed class definition's slots", {
    skip_if_not(nrow(avail) > 0L, "no subobject minis installed")

    for (i in seq_len(nrow(avail))) {
        type <- avail$type[[i]]
        obj <- loadSubObjectMini(type, idx = avail$index[[i]])
        stored <- setdiff(names(attributes(obj)), "class")
        defined <- names(methods::getSlots(class(obj)[[1L]]))
        # no slot the definition expects is absent, and none the file carried
        # survives that the definition has since dropped
        expect_setequal(stored, defined)
    }
})

test_that("the network minis are migrated off their pre-0.6.0 slots", {
    # written with @networkDT / @networkDT_before_filter and @igraph; the
    # migration in initialize() moves them to @network / @unfiltered.
    for (idx in seq_len(nrow(listSubObjectMini("spatialNetworkObj")))) {
        sn <- loadSubObjectMini("spatialNetworkObj", idx = idx)
        expect_s3_class(slot(sn, "network"), "igraph")
        expect_null(attr(sn, "networkDT", exact = TRUE))
        expect_gt(igraph::vcount(slot(sn, "network")), 0L)
        expect_gt(igraph::ecount(slot(sn, "network")), 0L)
    }

    nn <- loadSubObjectMini("nnNetObj")
    expect_s3_class(slot(nn, "network"), "igraph")
    expect_null(attr(nn, "igraph", exact = TRUE))
    expect_gt(igraph::vcount(slot(nn, "network")), 0L)
})

test_that("the polygon mini carries current overlaps, not intersection SpatVectors", {
    # saved before GiottoClass 0.4.7; unwrapping keeps the old representation,
    # which the current polygon subsetting indexes by point row
    for (idx in seq_len(nrow(listSubObjectMini("giottoPolygon")))) {
        gp <- loadSubObjectMini("giottoPolygon", idx = idx)
        ovlps <- slot(gp, "overlaps")
        ovlps <- ovlps[names(ovlps) != "intensity"]
        for (o in ovlps) {
            expect_s4_class(o, "overlapInfo")
            expect_false(inherits(o, "SpatVector"))
        }
    }
})

test_that("the spatialGridObj mini is the subobject, not its gridDT", {
    sg <- loadSubObjectMini("spatialGridObj")
    expect_s4_class(sg, "spatialGridObj")
    expect_s3_class(slot(sg, "gridDT"), "data.table")
})

test_that("image minis are reconnected to readable rasters", {
    for (idx in seq_len(nrow(listSubObjectMini("giottoLargeImage")))) {
        img <- loadSubObjectMini("giottoLargeImage", idx = idx)
        expect_s4_class(img, "giottoLargeImage")
        # a dead terra pointer errors here rather than returning dimensions
        expect_length(as.vector(terra::ext(slot(img, "raster_object"))), 4L)
    }
})
