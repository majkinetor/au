#requires -version 5

$s = {
    chocolatey
    psgallery
    git
    pester
}

function git() {
    if (!(gcm git -ea ignore)) { cinst git }
    Write-Host "Git version: " $(git --version)
}

function pester() {
    Write-Host Installing pester
    inmo pester #3.4.3
    $version = gmo pester -ListAvailable | % { $_.Version.ToString() }
    Write-Host "Pester version: $version"
}

function chocolatey() {
    #if (!(gcm choco -ea ignore)) {
        iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
        Write-Host "Chocolatey version: " $(choco -v)
    #}
}

function psgallery() {
    Install-PackageProvider -Name NuGet -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

& $s
