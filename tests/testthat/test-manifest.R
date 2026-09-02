
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

test_that("recorded checksums are accepted and kept honest", {
    base <- list(a = list(files = list(spatial_locs = "https://example.com/x.txt")))

    ok <- base
    ok$a$checksums <- list(x.txt = paste0("sha256:", strrep("a", 64)))
    expect_true(GiottoData:::.gdata_manifest_validate(ok))

    # md5 from a source that publishes md5 is equally valid
    ok$a$checksums <- list(x.txt = paste0("md5:", strrep("b", 32)))
    expect_true(GiottoData:::.gdata_manifest_validate(ok))

    bad <- base; bad$a$checksums <- list(x.txt = strrep("a", 64))     # no algo
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "must read")

    bad <- base; bad$a$checksums <- list(x.txt = "sha256:zzzz")       # not hex
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "must read")

    bad <- base; bad$a$checksums <- list()
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "non-empty named list")

    # the one thing this can still catch: a url changed without its checksum,
    # leaving a recorded value that no longer describes anything downloaded
    bad <- base
    bad$a$checksums <- list(gone.txt = paste0("sha256:", strrep("a", 64)))
    expect_error(GiottoData:::.gdata_manifest_validate(bad), "does not")
})

test_that("checksums survive a write as scalars, not one-element arrays", {
    p <- withr::local_tempfile(fileext = ".json")
    m <- list(a = list(
        files = list(bundle = "https://example.com/b.zip"),
        checksums = list(b.zip = paste0("sha256:", strrep("a", 64))),
        extract = TRUE
    ))
    GiottoData:::.gdata_manifest_write(m, path = p)

    txt <- readLines(p)
    sum_line <- grep('"b.zip"', txt, value = TRUE)
    expect_length(sum_line, 1L)
    expect_false(grepl(":\\s*\\[", sum_line))          # scalar, not array
    expect_true(grepl(':\\s*"sha256:', sum_line))

    back <- GiottoData:::.gdata_manifest(p)
    expect_identical(back$a$checksums$b.zip, m$a$checksums$b.zip)
    expect_true(GiottoData:::.gdata_manifest_validate(back))
})

test_that("the shipped manifest's checksums are well formed", {
    m <- GiottoData:::.gdata_manifest()
    n <- 0L
    for (ds in names(m)) {
        sums <- m[[ds]][["checksums"]]
        if (is.null(sums)) next
        for (fn in names(sums)) {
            expect_match(tolower(sums[[fn]]),
                         "^(md5|sha1|sha256|sha512):[0-9a-f]+$", info = paste(ds, fn))
            n <- n + 1L
        }
    }
    expect_gt(n, 0L)
})
