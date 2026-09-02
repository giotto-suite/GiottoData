# Run on library loading

.onLoad <- function(libname, pkgname) {
    # NULL means "use the standard per-user cache location". Seeded rather
    # than assigned so a value set in an .Rprofile survives loading.
    init_option("giottodata.cache", NULL)
}

# print version number
.onAttach <- function(libname, pkgname) {
    packageStartupMessage("GiottoData ", utils::packageVersion("GiottoData"))
}
