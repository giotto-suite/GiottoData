# Run on library loading

# print version number
.onAttach <- function(libname, pkgname) {
    packageStartupMessage("GiottoData ", utils::packageVersion("GiottoData"))
}
