# Author: Josh Ameli <contact@jekotia.net>
# Based off of the Git plugin by Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 20-Aug-2019.

# https://www.appveyor.com/docs/how-to/git-push/

param(
    $Info,

    # GitLab username
    [string] $User,

    # GitLab API key.
    [string] $API_Key,

    # Repository HTTP(S) URL
    [string]$PushURL,

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

pushd $root
$origin  = git config --get remote.origin.url
$origin -match '(?<=:/+)[^/]+' | Out-Null
$machine = $Matches[0]

### Construct RepoURL to be set as new origin
$RepoURL = (
    $PushURL.split('://')[0] `
    + "://" `
    + $User `
    + ":" `
    + $API_Key `
    + "@" `
    + $PushURL.TrimStart(
        $(
            $PushURL.split('://')[0] `
            + "://"
        )
    )
)

### Set new push URL
git remote set-url origin $RepoURL

### Ensure local is up-to-date to avoid conflicts
Write-Host "Executing git pull"
git checkout -q $Branch
git pull -q origin $Branch

### Commit
if  ($commitStrategy -like 'atomic*') {
    $packages | % {
        Write-Host "Adding update package to git repository: $($_.Name)"
        git add -u $_.Path
        git status

        Write-Host "Commiting $($_.Name)"
        $message = "AU: $($_.Name) upgraded from $($_.NuspecVersion) to $($_.RemoteVersion)"
        $gist_url = $Info.plugin_results.Gist -split '\n' | select -Last 1
        $snippet_url = $Info.plugin_results.Snippet -split '\n' | select -Last 1
        git commit -m "$message`n[skip ci] $gist_url $snippet_url" --allow-empty

        if ($commitStrategy -eq 'atomictag') {
          $tagcmd = "git tag -a $($_.Name)-$($_.RemoteVersion) -m '$($_.Name)-$($_.RemoteVersion)'"
          Invoke-Expression $tagcmd
        }
    }
}
else {
    Write-Host "Adding updated packages to git repository: $( $packages | % Name)"
    $packages | % { git add -u $_.Path }
    git status

    Write-Host "Commiting"
    $message = "AU: $($packages.Length) updated - $($packages | % Name)"
    $gist_url = $Info.plugin_results.Gist -split '\n' | select -Last 1
    $snippet_url = $Info.plugin_results.Snippet -split '\n' | select -Last 1
    git commit -m "$message`n[skip ci] $gist_url $snippet_url" --allow-empty

}

### Push
Write-Host "Pushing changes"
git push -q 
if ($commitStrategy -eq 'atomictag') {
    write-host 'Atomic Tag Push'
    git push -q --tags
}
popd

git remote set-url origin $origin
