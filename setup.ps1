#requires -version 5

#Setup chocolatey
if (!(gcm choco -ea ignore)) {
    iwr https://chocolatey.org/install.ps1 -UseBasicParsing | iex
}

#Setup Powershell Gallery
Install-PackageProvider -Name NuGet -Force
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

cinst git
install-module pester
