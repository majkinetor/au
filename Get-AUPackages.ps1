function Get-AUPackages($Name=$null) {
    ls .\*\update.ps1 | % {
        $packageDir = gi (Split-Path $_)
        if ($packageDir.Name -like '_*') { return }
        if ($Name) {
            if ( $packageDir.Name -like "$Name" ) { $packageDir }
        } else { $packageDir }
    }
}
Set-Alias gup  Get-AuPackages
