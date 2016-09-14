#requires -version 5

$s = {
    chocolatey
    psgallery
    if (!(gcm git -ea ignore)) { cinst git }
    inmo pester #3.4.3
}

function chocolatey() {
    #if (!(gcm choco -ea ignore)) {
        iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
        choco -v
    #}
}

function psgallery() {
    Install-PackageProvider -Name NuGet -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

& $s
