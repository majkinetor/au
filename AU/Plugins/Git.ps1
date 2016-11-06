# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 06-Nov-2016.

# https://www.appveyor.com/docs/how-to/git-push/

param(
    $Info,

    # Git username
    [string] $User,

    # Git password. You can use Github Token here if you omit username.
    [string] $Password,

    #Force git commit when package is updated but not pushed.
    [switch] $Force
)

[array]$packages = if ($Force) { $Info.result.updated } else { $Info.result.pushed }
if ($packages.Length -eq 0) { Write-Host "No package updated, skipping"; return }

$root = Split-Path $packages[0].Path
pushd $root
$origin  = git config --get remote.origin.url
$origin -match '(?<=:/+)[^/]+' | Out-Null
$machine = $Matches[0]

if ($User -and $Password) {
    Write-Host "Setting credentials for: $machine"

    if ( "machine $server" -notmatch (gc ~/_netrc)) {
        Write-Host "Credentials already found for machine: $machine"
    }
    "machine $machine", "login $User", "password $Password" | Out-File -Append ~/_netrc -Encoding ascii
} elseif ($Password) {
    Write-Host "Setting oauth token for: $machine"
    git config --global credential.helper store
    Add-Content "$env:USERPROFILE\.git-credentials" "https://${Password}:x-oauth-basic@$machine`n"
}

Write-Host "Executing git pull"
git checkout -q master
git pull -q origin master

Write-Host "Adding updated packages to git repository: $( $packages | % Name)"
$packages | % { git add -u $_.Name }
git status

Write-Host "Commiting"
$Message = "AU: $($packages.Length) updated - $($packages | % Name)"
git commit -m "$Message [skip ci]"

Write-Host "Pushing changes"
git push -q

popd
