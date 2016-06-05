function Test-Package() {
    cpack
    cinst (gi *.nupkg).Name --source $pwd --force
}
