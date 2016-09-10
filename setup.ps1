#requires -version 5

$s = {

    chocolatey
    psgallery
    cinst git
    inmo pester
}

function chocolatey() {
    if (!(gcm choco -ea ignore)) {
        iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
    }
}

function psgallery() {
    Install-PackageProvider -Name NuGet -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

& $s
