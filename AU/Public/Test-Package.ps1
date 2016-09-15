#https://github.com/chocolatey/choco/wiki/CreatePackages#testing-your-package

function Test-Package {
    param(
        # If file, path to the .nupkg or .nuspec file for the package.
        # If directory, latest .nupkg or .nuspec file wil be looked in it.
        # If ommited current directory will be used.
        $Nu
    )
    if (!$Nu) { $dir = gi $pwd }
    else {
        if (!(Test-Path $Nu)) { throw "Path not found: $Nu" }
        $Nu = gi $Nu
        $dir = if ($Nu.PSIsContainer) { $Nu; $Nu = $null } else { $Nu.Directory }
    }

    if (!$Nu) {
        $Nu = gi $dir/*.nupkg | sort -Property CreationTime -Descending | select -First 1
        if (!$Nu) { $Nu = gi $dir/*.nuspec }
        if (!$Nu) { throw "Can't find nupkg or nuspec file in the directory" }
    }

    if ($Nu.Extension -eq '.nuspec') {
        Write-Host "Nuspec file given, running choco pack"
        choco pack -r $Nu.FullName --OutputDirectory $Nu.DirectoryName | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "choco pack failed with $LastExitCode"}
        $Nu = gi "$($Nu.DirectoryName)\*.nupkg" | sort -Property CreationTime -Descending | select -First 1
    } elseif ($Nu.Extension -ne '.nupkg') { throw "File is not nupkg or nuspec file" }

    $package_name    = $Nu.Name -replace '(\.\d+)+\.nupkg$'
    $package_version = ($Nu.BaseName -replace $package_name).Substring(1)

    Write-Host "`nPackage info"
    Write-Host "  Path:".PadRight(15)     $Nu
    Write-Host "  Name:".PadRight(15)     $package_name
    Write-Host "  Version:".PadRight(15)  $package_version

    Write-Host "`nTesting package install"
    choco install -r $package_name --version $package_version --source "'$($Nu.DirectoryName);https://chocolatey.org/api/v2/'" --force | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "choco install failed with $LastExitCode"}

    Write-Host "`nTesting package uninstall"
    choco uninstall -r $package_name | Write-Host
    if ($LASTEXITCODE -ne 0) { throw "choco uninstall failed with $LastExitCode"}
}
