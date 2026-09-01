
# a minimal valid manifest to mutate per-case
valid <- function() {
    list(
        ds_a = list(
            files = list(
                spatial_locs = "https://example.com/a/coord.txt",
                metadata = c("https://example.com/a/m1.txt", "https://example.com/a/m2.csv")
            )
        ),
        ds_b = list(
            files = list(bundle = "https://example.com/b/Raw.zip"),
            extract = TRUE
        )
    )
}

test_that("the shipped manifest is valid", {
    expect_true(GiottoData:::.gdata_manifest_validate(GiottoData:::.gdata_manifest()))
})

test_that("the shipped manifest agrees with the exported listers", {
    m <- GiottoData:::.gdata_manifest()
    expect_identical(listSpatialDatasetNames(), names(m))
    expect_setequal(
        listSpatialDatasetCategories(),
        unique(unlist(lapply(m, function(x) names(x$files))))
    )
})

test_that("a well formed manifest validates", {
    expect_true(GiottoData:::.gdata_manifest_validate(valid()))
})

test_that("shape errors are caught", {
    bad <- valid(); bad$ds_a$files <- list()
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "non-empty named list")

    bad <- valid(); bad$ds_a$files$spatial_locs <- ""
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "empty or NA url")

    bad <- valid(); bad$ds_a$files$spatial_locs <- NA_character_
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "empty or NA url")

    bad <- valid(); bad$ds_a$files$spatial_locs <- "ftp://example.com/x.txt"
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "not an http")

    bad <- valid(); bad$ds_b$extract <- "yes"
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "single TRUE or FALSE")

    bad <- valid(); bad$ds_a$extrct <- TRUE
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "unknown key")

    # all files land in one flat directory, so basenames must not collide
    bad <- valid(); bad$ds_a$files$metadata <- c("https://example.com/x/coord.txt",
                                                 "https://example.com/a/m2.csv")
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "duplicate filename")
})

test_that("write/read round trips and preserves json shape", {
    p <- withr::local_tempfile(fileext = ".json")
    m <- valid()

    expect_identical(GiottoData:::.gdata_manifest_write(m, path = p), p)
    back <- GiottoData:::.gdata_manifest(p)

    expect_identical(names(back), names(m))
    expect_identical(lapply(back, `[[`, "files"), lapply(m, `[[`, "files"))
    expect_true(isTRUE(back$ds_b$extract))
    expect_null(back$ds_a$extract)

    txt <- readLines(p)
    # single-url categories must stay arrays, not collapse to bare strings
    cats <- grep('^\\s+"(spatial_locs|metadata|bundle)":', txt, value = TRUE)
    expect_length(cats, 3L)
    expect_true(all(grepl(":\\s*\\[", cats)))
    # extract must be a bare boolean, not [true]
    expect_true(any(grepl('"extract":\\s*true\\s*$', txt)))
})

test_that("the writer refuses an invalid manifest without touching disk", {
    p <- withr::local_tempfile(fileext = ".json")
    bad <- valid(); bad$ds_a$files$spatial_locs <- "not-a-url"

    expect_error(GiottoData:::.gdata_manifest_write(bad, path = p), "not an http")
    expect_false(file.exists(p))
})
