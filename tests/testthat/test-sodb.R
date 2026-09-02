
test_that("sodb cache paths are namespaced and keyed on the experiment", {
    f <- GiottoData:::.sodb_cache_file
    d <- "/tmp/cache"

    expect_identical(f("Dataset_A", "exp1", d),
                     file.path(d, "sodb", "Dataset_A__exp1.h5ad"))

    # namespaced so a SODB name cannot collide with a spatial dataset dir
    expect_identical(basename(dirname(f("Dataset_A", "exp1", d))), "sodb")

    # a second experiment of the same dataset is a distinct file, which the
    # previous hardcoded filename could not represent
    expect_false(identical(f("Dataset_A", "exp1", d), f("Dataset_A", "exp2", d)))
    expect_false(identical(f("Dataset_A", "exp1", d), f("Dataset_B", "exp1", d)))
})

test_that("sodb cache filenames are filesystem safe", {
    f <- GiottoData:::.sodb_cache_file
    d <- "/tmp/cache"

    # SODB names are external text and may contain anything
    p <- f("Mouse Brain (2020)", "rep/1", d)
    expect_false(grepl("[ /()]", basename(p)))
    expect_true(grepl("[.]h5ad$", basename(p)))

    # separators are collapsed, which is what keeps the result inside the
    # cache directory. A literal ".." within the filename is harmless.
    p2 <- f("../../etc/passwd", "default", d)
    expect_identical(dirname(p2), file.path(d, "sodb"))
    expect_false(grepl("/", basename(p2)))

    # never produce a hidden file
    expect_false(startsWith(basename(f(".hidden", "default", d)), "."))

    # deterministic
    expect_identical(f("a b", "x", d), f("a b", "x", d))
})

test_that("sodb cache defaults to the package cache", {
    expect_identical(
        eval(formals(getSODBDataset)$directory),
        giottoDataCache()
    )
    expect_identical(
        dirname(GiottoData:::.sodb_cache_file("d", "e")),
        giottoDataCache("sodb")
    )
})

test_that("getSODBDataset errors before touching python when misused", {
    # a missing dataset name must fail on argument checking, not on a python
    # environment the caller may not have
    expect_error(getSODBDataset(), "dataset name must be provided")
})
