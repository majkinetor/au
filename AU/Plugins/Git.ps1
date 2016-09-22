# https://www.appveyor.com/docs/how-to/git-push/

param(
    $Info,

    # Git username
    [string] $User,

    # Git password. You can use Github Token here if you omit username.
    [string] $Password
)

if (!$Info.pushed) { Write-Host "  No package is pushed to Chocolatey community feed, skipping"; return }

$root = Split-Path $Info.pushed[0].Path
pushd $root

$Message = "AU: $Info.Pushed updated: " + "$($Info.result.pushed | % Name)"

$origin = git config --get remote.origin.url
$machine = $origin -match '(?<=:/+)[^/]+'; $Matches[0]

if ($User -and $Password) {
    Write-Host 'Setting credentials'

    if ( "machine $server" -notmatch (gc ~/_netrc)) {
        Write-Host "Github credentials already found for machine: $machine."
    }
    "machine $server", "login $User", "password $Password" | Out-File -Append ~/_netrc -Encoding ascii
} elseif ($Password) {
    Write-Host 'Setting oauth token'
    Add-Content "$env:USERPROFILE\.git-credentials" "https://$Password:x-oauth-basic@$machine`n"
}


$pushed = $Info.result.pushed

""
"Executing git pull"
git checkout master
git pull

"Commiting updated packages to git repository"
$pushed | % { git add $_.Name }

$s = if ($Info.pushed -gt 1) { 's' } else { '' }
git commit -m "$Message [skip ci]"

"Pushing git changes"
git push

popd $root
