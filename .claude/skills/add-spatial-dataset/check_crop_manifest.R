#!/usr/bin/env Rscript
# Check a cropped dataset's crop_manifest.json against crop_manifest.schema.json.
#
#   Rscript check_crop_manifest.R <archive.zip | crop_manifest.json> [dataset_name]
#
# Given an archive, also checks that every file not marked dropped is in it.
# Given a dataset name, checks fixture_name matches it. Exits 1 on any failure.

args <- commandArgs(trailingOnly = TRUE)
if (!length(args) %in% 1:2) {
    stop("[check_crop_manifest] usage: check_crop_manifest.R <archive.zip | crop_manifest.json> [dataset_name]",
         call. = FALSE)
}
path <- args[[1]]

script_dir <- dirname(normalizePath(sub("^--file=", "",
    grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])))
schema <- file.path(script_dir, "crop_manifest.schema.json")

failures <- character()
fail <- function(...) failures <<- c(failures, paste0(...))

# the archive's entries, with a single wrapping folder stripped as
# getSpatialDataset() does on extraction
entries <- NULL
if (grepl("\\.zip$", path)) {
    entries <- utils::unzip(path, list = TRUE)$Name
    top <- unique(sub("/.*", "", entries))
    if (length(top) == 1L && all(startsWith(entries, paste0(top, "/")))) {
        entries <- substring(entries, nchar(top) + 2L)
    }
    entries <- entries[nzchar(entries)]
    inner <- grep("(^|/)crop_manifest\\.json$", utils::unzip(path, list = TRUE)$Name,
                  value = TRUE)
    if (!"crop_manifest.json" %in% entries) {
        stop("[check_crop_manifest] no crop_manifest.json at the archive root", call. = FALSE)
    }
    json <- paste(readLines(unz(path, inner[[1]]), warn = FALSE), collapse = "\n")
} else {
    json <- paste(readLines(path, warn = FALSE), collapse = "\n")
}

ok <- jsonvalidate::json_validate(json, schema, engine = "ajv", verbose = TRUE)
if (!ok) {
    errs <- attr(ok, "errors")
    fail(sprintf("schema: %s %s", ifelse(nzchar(errs$instancePath), errs$instancePath, "/"),
                 errs$message))
}

m <- jsonlite::fromJSON(json, simplifyVector = FALSE)

if (length(args) == 2L && !identical(m$fixture_name, args[[2]])) {
    fail(sprintf("fixture_name is '%s', expected '%s'", m$fixture_name, args[[2]]))
}

if (!is.null(entries)) {
    for (f in m$files) {
        if (identical(f$action, "dropped")) next
        present <- if (endsWith(f$file, "/")) any(startsWith(entries, f$file))
                   else f$file %in% entries || any(startsWith(entries, paste0(f$file, "/")))
        if (!present) fail(sprintf("files: '%s' is marked %s but is not in the archive", f$file, f$action))
    }
}

if (length(failures)) {
    cat(paste0("FAIL ", failures), sep = "\n")
    quit(status = 1L)
}
cat("OK", m$fixture_name, "\n")
