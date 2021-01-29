#requires -version 5

$s = {
    chocolatey
    psgallery
    git_4windows

    pester
    cinst papercut
}

function git_4windows() {
    if (!(Get-Command git -ea ignore)) { "Installing git"; cinst git }
    git --version
}

function pester() {
    "Installing pester"

    inmo pester -Force -MaximumVersion 4.10.1 #3.4.3
    $version = Get-Module pester -ListAvailable | ForEach-Object { $_.Version.ToString() }
    "Pester version: $version"
}

function chocolatey() {
    "Installing chocolatey"

    Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression
    "Chocolatey version: $(choco -v)"
}

function psgallery() {
    "Installing PSGallery"

    Install-PackageProvider -Name NuGet -Force
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
}

& $s
