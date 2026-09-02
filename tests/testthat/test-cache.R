
test_that("the default cache location is the standard per-user one", {
    withr::local_options(list(giottodata.cache = NULL))
    expect_identical(giottoDataCache(), tools::R_user_dir("GiottoData", "cache"))
})

test_that("path components compose onto the root", {
    withr::local_options(list(giottodata.cache = "/tmp/gdc"))
    expect_identical(giottoDataCache(), "/tmp/gdc")
    expect_identical(giottoDataCache("a"), "/tmp/gdc/a")
    expect_identical(giottoDataCache("a", "b.txt"), "/tmp/gdc/a/b.txt")
})

test_that("the option overrides the default and is respected by callers", {
    withr::local_options(list(giottodata.cache = "/tmp/gdc_opt"))
    expect_identical(giottoDataCache(), "/tmp/gdc_opt")
    # both download functions resolve their default through it
    expect_identical(eval(formals(getSpatialDataset)$directory), "/tmp/gdc_opt")
    expect_identical(eval(formals(getSODBDataset)$directory), "/tmp/gdc_opt")
    expect_identical(
        dirname(GiottoData:::.sodb_cache_file("d", "e")),
        "/tmp/gdc_opt/sodb"
    )
})

test_that("set= assigns the option and returns the new root invisibly", {
    withr::local_options(list(giottodata.cache = NULL))

    res <- withVisible(giottoDataCache(set = "/tmp/gdc_set"))
    expect_false(res$visible)
    expect_identical(res$value, "/tmp/gdc_set")
    expect_identical(getOption("giottodata.cache"), "/tmp/gdc_set")
    expect_identical(giottoDataCache("x"), "/tmp/gdc_set/x")

    # NULL clears it, restoring the default
    giottoDataCache(set = NULL)
    expect_null(getOption("giottodata.cache"))
    expect_identical(giottoDataCache(), tools::R_user_dir("GiottoData", "cache"))
})

test_that("set= expands ~ so the stored value is usable", {
    withr::local_options(list(giottodata.cache = NULL))
    giottoDataCache(set = "~/gdc_tilde")
    expect_false(startsWith(getOption("giottodata.cache"), "~"))
    expect_identical(getOption("giottodata.cache"), path.expand("~/gdc_tilde"))
})

test_that("set= rejects values that are not a single path", {
    withr::local_options(list(giottodata.cache = NULL))
    expect_error(giottoDataCache(set = c("a", "b")), "single path")
    expect_error(giottoDataCache(set = ""), "single path")
    expect_error(giottoDataCache(set = NA_character_), "single path")
    expect_error(giottoDataCache(set = 1), "single path")
    # a rejected set must not have changed anything
    expect_null(getOption("giottodata.cache"))
})

test_that("an unusable option value falls back rather than erroring", {
    # a stale or malformed .Rprofile value should not break every download
    for (bad in list(NA_character_, "", character(), c("a", "b"), 1)) {
        withr::local_options(list(giottodata.cache = bad))
        expect_identical(
            giottoDataCache(),
            tools::R_user_dir("GiottoData", "cache")
        )
    }
})

test_that("calling it creates nothing", {
    withr::local_options(list(giottodata.cache = file.path(tempdir(), "gdc_none")))
    p <- giottoDataCache("sub")
    expect_false(dir.exists(p))
    expect_false(dir.exists(dirname(p)))
})
