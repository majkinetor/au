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

$packages = if ($Force) { $Info.result.updated } else { $Info.result.pushed }
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
    "machine $server", "login $User", "password $Password" | Out-File -Append ~/_netrc -Encoding ascii
} elseif ($Password) {
    Write-Host 'Setting oauth token'
    Add-Content "$env:USERPROFILE\.git-credentials" "https://$Password:x-oauth-basic@$machine`n"
}

Write-Host "Executing git pull"
git pull origin master

Write-Host "Adding updated packages to git repository: $( $packages | % Name);"
$packages | % { git add $_.Name }

Write-Host "Commiting"
$Message = "AU: $($packages.Length) updated: " + "$($packages | % Name)"
git commit -m "$Message [skip ci]"

Write-Host "Pushing changes"
git push

popd $root
