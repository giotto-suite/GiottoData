
test_that("archive types are recognised, compressed data files are not", {
    at <- GiottoData:::.gdata_archive_type
    expect_identical(at("x.zip"), "zip")
    expect_identical(at("X.ZIP"), "zip")
    for (f in c("x.tar", "x.tgz", "x.tar.gz", "x.tar.bz2", "x.tar.xz", "x.tbz2")) {
        expect_identical(at(f), "tar", info = f)
    }
    # gzipped count matrices are meant to be read compressed
    expect_true(is.na(at("expr.txt.gz")))
    expect_true(is.na(at("coord.txt")))
    expect_true(is.na(at("seg.geojson")))
})

test_that("packaging noise is identified", {
    jk <- GiottoData:::.gdata_archive_junk
    expect_true(all(jk(c("__MACOSX/._a", ".DS_Store", "Raw/.DS_Store", "Raw/._a.tif"))))
    expect_false(any(jk(c("Raw/a.tif", "cells.parquet", "morphology/x.tif"))))
})

test_that("a single wrapping directory is detected, ignoring noise", {
    ar <- GiottoData:::.gdata_archive_root
    expect_identical(ar(c("Raw/", "Raw/a.tif", "Raw/b.csv")), "Raw")
    expect_identical(ar(c("Raw/", "Raw/a.tif", "__MACOSX/Raw/._a.tif", "Raw/.DS_Store")), "Raw")

    # nothing to strip
    expect_true(is.na(ar(c("cells.parquet", "transcripts.parquet"))))
    expect_true(is.na(ar(c("a/x.txt", "b/y.txt"))))
    expect_true(is.na(ar("only.csv")))
    expect_true(is.na(ar(c("__MACOSX/", "__MACOSX/._x"))))
    expect_true(is.na(ar(character())))
})

test_that("the extraction stamp round trips", {
    d <- withr::local_tempdir()
    expect_identical(GiottoData:::.gdata_stamp_read(d), list())
    expect_identical(GiottoData:::.gdata_extracted_ok(d), character())

    GiottoData:::.gdata_stamp_write(d, list(a.zip = c("one.txt", "two.txt")))
    expect_identical(GiottoData:::.gdata_stamp_read(d)$a.zip, c("one.txt", "two.txt"))

    # recorded but absent from disk -> not satisfied
    expect_identical(GiottoData:::.gdata_extracted_ok(d), character())
    file.create(file.path(d, c("one.txt", "two.txt")))
    expect_identical(GiottoData:::.gdata_extracted_ok(d), "a.zip")

    # one member removed -> no longer satisfied
    unlink(file.path(d, "two.txt"))
    expect_identical(GiottoData:::.gdata_extracted_ok(d), character())
})

test_that("extraction strips the wrapper, drops noise, and removes the archive", {
    skip_if(Sys.which("zip") == "", "no zip binary")

    src <- withr::local_tempdir()
    dir.create(file.path(src, "Raw"))
    writeLines("a", file.path(src, "Raw", "a.txt"))
    writeLines("b", file.path(src, "Raw", "b.txt"))
    writeLines("junk", file.path(src, "Raw", ".DS_Store"))
    dir.create(file.path(src, "__MACOSX"))
    writeLines("junk", file.path(src, "__MACOSX", "._a.txt"))

    dest <- withr::local_tempdir()
    archive <- file.path(dest, "bundle.zip")
    old <- setwd(src); on.exit(setwd(old), add = TRUE)
    utils::zip(archive, files = c("Raw", "__MACOSX"), flags = "-rq")
    setwd(old)
    skip_if(!file.exists(archive), "zip did not produce an archive")

    GiottoData:::.gdata_extract(archive, dest, verbose = FALSE)

    expect_true(file.exists(file.path(dest, "a.txt")))
    expect_true(file.exists(file.path(dest, "b.txt")))
    expect_false(dir.exists(file.path(dest, "Raw")))
    expect_false(dir.exists(file.path(dest, "__MACOSX")))
    expect_false(file.exists(file.path(dest, ".DS_Store")))
    expect_false(file.exists(archive))

    # stamp records the post-strip paths, and marks the archive satisfied
    expect_setequal(GiottoData:::.gdata_stamp_read(dest)$bundle.zip, c("a.txt", "b.txt"))
    expect_identical(GiottoData:::.gdata_extracted_ok(dest), "bundle.zip")

    # re-running with the archive already gone is a no-op, not an error
    expect_no_error(GiottoData:::.gdata_extract(archive, dest, verbose = FALSE))
    expect_true(file.exists(file.path(dest, "a.txt")))
})

test_that("a wrapper name with regex metacharacters is stripped exactly", {
    skip_if(Sys.which("zip") == "", "no zip binary")

    # wrapper names are arbitrary vendor text; a regex-based strip would
    # mis-handle this and silently leave the stamp empty, causing a re-download
    wrapper <- "SAW_v8.2.0(final)"

    src <- withr::local_tempdir()
    dir.create(file.path(src, wrapper, "image"), recursive = TRUE)
    writeLines("x", file.path(src, wrapper, "cells.parquet"))
    writeLines("y", file.path(src, wrapper, "image", "he.tif"))

    dest <- withr::local_tempdir()
    archive <- file.path(dest, "bundle.zip")
    old <- setwd(src); on.exit(setwd(old), add = TRUE)
    utils::zip(archive, files = wrapper, flags = "-rq")
    setwd(old)
    skip_if(!file.exists(archive), "zip did not produce an archive")

    GiottoData:::.gdata_extract(archive, dest, verbose = FALSE)

    expect_true(file.exists(file.path(dest, "cells.parquet")))
    expect_true(file.exists(file.path(dest, "image", "he.tif")))
    expect_false(dir.exists(file.path(dest, wrapper)))

    # the stamp must record post-strip paths, or the archive is treated as
    # never extracted and gets downloaded again
    expect_true("cells.parquet" %in% GiottoData:::.gdata_stamp_read(dest)$bundle.zip)
    expect_identical(GiottoData:::.gdata_extracted_ok(dest), "bundle.zip")
})

test_that("nested directories survive the wrapper strip", {
    skip_if(Sys.which("zip") == "", "no zip binary")

    src <- withr::local_tempdir()
    dir.create(file.path(src, "Bundle", "morphology_focus"), recursive = TRUE)
    dir.create(file.path(src, "Bundle", "cell_feature_matrix"), recursive = TRUE)
    writeLines("a", file.path(src, "Bundle", "cells.parquet"))
    writeLines("b", file.path(src, "Bundle", "morphology_focus", "f0.ome.tif"))
    writeLines("c", file.path(src, "Bundle", "cell_feature_matrix", "barcodes.tsv"))

    dest <- withr::local_tempdir()
    archive <- file.path(dest, "b.zip")
    old <- setwd(src); on.exit(setwd(old), add = TRUE)
    utils::zip(archive, files = "Bundle", flags = "-rq")
    setwd(old)
    skip_if(!file.exists(archive), "zip did not produce an archive")

    GiottoData:::.gdata_extract(archive, dest, verbose = FALSE)

    expect_true(dir.exists(file.path(dest, "morphology_focus")))
    expect_true(dir.exists(file.path(dest, "cell_feature_matrix")))
    expect_true(file.exists(file.path(dest, "morphology_focus", "f0.ome.tif")))
    expect_true(file.exists(file.path(dest, "cell_feature_matrix", "barcodes.tsv")))
    # nothing was collapsed to the root
    expect_length(list.files(dest, pattern = "ome[.]tif$"), 0L)
})
