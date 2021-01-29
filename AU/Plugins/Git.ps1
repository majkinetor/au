# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 09-Nov-2016.

# https://www.appveyor.com/docs/how-to/git-push/

param(
    $Info,

    # Git username
    [string] $User,

    # Git password. You can use Github Token here if you omit username.
    [string] $Password,

    # Force git commit when package is updated but not pushed.
    [switch] $Force,

    # Commit strategy: 
    #  single    - 1 commit with all packages
    #  atomic    - 1 commit per package    
    #  atomictag - 1 commit and tag per package
    [ValidateSet('single', 'atomic', 'atomictag')]
    [string]$commitStrategy = 'single',

    # Branch name
    [string]$Branch = 'master'
)

[array]$packages = if ($Force) { $Info.result.updated } else { $Info.result.pushed }
if ($packages.Length -eq 0) { Write-Host "No package updated, skipping"; return }

$root = Split-Path $packages[0].Path
Push-Location $root
$origin  = git config --get remote.origin.url
$origin -match '(?<=:/+)[^/]+' | Out-Null
$machine = $Matches[0]

if ($User -and $Password) {
    Write-Host "Setting credentials for: $machine"

    if ( "machine $server" -notmatch (Get-Content ~/_netrc)) {
        Write-Host "Credentials already found for machine: $machine"
    }
    "machine $machine", "login $User", "password $Password" | Out-File -Append ~/_netrc -Encoding ascii
} elseif ($Password) {
    Write-Host "Setting oauth token for: $machine"
    git config --global credential.helper store
    Add-Content "$env:USERPROFILE\.git-credentials" "https://${Password}:x-oauth-basic@$machine`n"
}

Write-Host "Executing git pull"
git checkout -q $Branch
git pull -q origin $Branch


if  ($commitStrategy -like 'atomic*') {
    $packages | ForEach-Object {
        Write-Host "Adding update package to git repository: $($_.Name)"
        git add -u $_.Path
        git status

        Write-Host "Commiting $($_.Name)"
        $message = "AU: $($_.Name) upgraded from $($_.NuspecVersion) to $($_.RemoteVersion)"
        $gist_url = $Info.plugin_results.Gist -split '\n' | Select-Object -Last 1
        $snippet_url = $Info.plugin_results.Snippet -split '\n' | Select-Object -Last 1
        git commit -m "$message`n[skip ci] $gist_url $snippet_url" --allow-empty

        if ($commitStrategy -eq 'atomictag') {
          $tagcmd = "git tag -a $($_.Name)-$($_.RemoteVersion) -m '$($_.Name)-$($_.RemoteVersion)'"
          Invoke-Expression $tagcmd
        }
    }
}
else {
    Write-Host "Adding updated packages to git repository: $( $packages | % Name)"
    $packages | ForEach-Object { git add -u $_.Path }
    git status

    Write-Host "Commiting"
    $message = "AU: $($packages.Length) updated - $($packages | % Name)"
    $gist_url = $Info.plugin_results.Gist -split '\n' | Select-Object -Last 1
    $snippet_url = $Info.plugin_results.Snippet -split '\n' | Select-Object -Last 1
    git commit -m "$message`n[skip ci] $gist_url $snippet_url" --allow-empty

}
Write-Host "Pushing changes"
git push -q 
if ($commitStrategy -eq 'atomictag') {
    write-host 'Atomic Tag Push'
    git push -q --tags
}
Pop-Location
