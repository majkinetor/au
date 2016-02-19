function Test-Package() {
    cpack
    cinst (gi *.nupkg).Name --source $pwd --force
}

Set-Alias test Test-Package
