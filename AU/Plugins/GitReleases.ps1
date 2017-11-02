# Author: Kim Nordmo <kim.nordmo@gmail.com>
# Last Change: 29-Oct-2017.

<#
.SYNOPSIS
    Creates Github release for updated packages
#>
param(
    $Info,

    # Github API token to use when creating/checking releases and uploading artifacts
    [string]$ApiToken,

    # What kind of release should be created, either 1 release per date, or 1 release per package and version is supported.
    [ValidateSet('date', 'package')]
    [string]$releaseType,

    # The text that should be used in the header of the release.
    [string]$releaseHeader = $null,

    # The text that should be used in the description of the release.
    [string]$releaseDescription = $null,

    # The text that should be used in the description when a release is created for a stream (by default it uses the latest commit message).
    [string]$streamReleaseDescription = '',

    # The formatting to use when replacing <date> in release header/description and on date based releases.
    [string]$dateFormat = '{0:yyyy-MM-dd}',

    # Force creating a release when a package have been updated and not just been pushed.
    [switch]$Force
)

function GetOrCreateRelease() {
    param(
        [string]$tagName,
        [string]$releaseName,
        [string]$releaseDescription,
        [string]$repository,
        $headers)

    try {
        Write-Verbose "Checking for a release using the tag: $tagName..."
        $response = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/$repository/releases/tags/$tagName" -Headers $headers | ? tag_name -eq $tagName
        if ($response) {
            return $response
        }
    }
    catch {
    }

    $json = @{
        "tag_name"         = $tagName
        "target_commitish" = "master"
        "name"             = $releaseName
        "body"             = $releaseDescription
        "draft"            = $false
        "prerelease"       = $false
    } | ConvertTo-Json -Compress

    Write-Host "Creating the new release $tagName..."
    return Invoke-RestMethod -UseBasicParsing -Method Post -Uri "https://api.github.com/repos/$repository/releases" -Body $json -Headers $headers
}

[array]$packages = if ($Force) { $Info.result.updated } else { $Info.result.pushed }

if ($packages.Length -eq 0) { Write-Host "No package updated, skipping"; return }

$packagesToRelease = New-Object 'System.Collections.Generic.List[hashtable]'

$packages | % {
    if ($_.Streams) {
        $pkg = $_
        $data = ConvertFrom-Json ($pkg.Streams -replace '@', '' -replace '\s*=\s*', '":"' -replace '{\s*', '{"' -replace '\s*}', '"}' -replace '\s*;\s*', '","')
        ($data | Get-Member -MemberType NoteProperty).Name | % {
            $value = $data.$_
            $packagesToRelease.Add(@{
                    Name          = $pkg.Name
                    RemoteVersion = $value
                    NuFile        = Resolve-Path ("$($pkg.Path)/*.$($value).nupkg")
                })
        }
    }
    else {
        $packagesToRelease.Add(@{
                Name          = $_.Name
                NuspecVersion = $_.NuspecVersion
                RemoteVersion = $_.RemoteVersion
                NuFile        = Resolve-Path ("$($_.Path)/$($_.Name).$($_.RemoteVersion).nupkg")
            })
    }
}

$origin = git config --get remote.origin.url

if (!($origin -match "github.com\/([^\/]+\/[^\/\.]+)")) {
    Write-Warning "Unable to parse the repository information, skipping..."
    return;
}
$repository = $Matches[1]

$headers = @{
    Authorization = "token $ApiToken"
}

if ($releaseType -eq 'date' -and !$releaseHeader) {
    $releaseHeader = 'Packages updated on <date>'
}
elseif (!$releaseHeader) {
    $releaseHeader = '<PackageName> <RemoteVersion>'
}

if ($releaseType -eq 'date' -and !$releaseDescription) {
    $releaseDescription = 'We had packages that was updated on <date>'
}
elseif (!$releaseDescription) {
    $releaseDescription = '<PackageName> was updated from version <NuspecVersion> to <RemoteVersion>'
}

$date = Get-Date -UFormat $dateFormat

if ($releaseType -eq 'date') {
    $release = GetOrCreateRelease `
        -tagName $date `
        -releaseName ($releaseHeader -replace '<date>', $date) `
        -releaseDescription ($releaseDescription -replace '<date>', $date) `
        -repository $repository `
        -headers $headers

    if (!$release) {
        Write-Error "Unable to create a new release, please check your permissions..."
        return
    }
}

$uploadHeaders = $headers.Clone()
$uploadHeaders['Content-Type'] = 'application/zip'

$packagesToRelease | % {
    # Because we grab all streams previously, we need to ignore
    # cases when a stream haven't been updated (no nupkg file created)
    if (!$_.NuFile) { return }

    if ($releaseType -eq 'package') {
        $releaseName = $releaseHeader -replace '<PackageName>', $_.Name -replace '<RemoteVersion>', $_.RemoteVersion -replace '<NuspecVersion>', $_.NuspecVersion -replace '<date>', $date
        if ($_.NuspecVersion) {
            $packageDesc = $releaseDescription
        }
        else {
            $packageDesc = $streamReleaseDescription
        }
        $packageDesc = $packageDesc -replace '<PackageName>', $_.Name -replace '<RemoteVersion>', $_.RemoteVersion -replace '<NuspecVersion>', $_.NuspecVersion -replace '<date>', $date

        $release = GetOrCreateRelease `
            -tagName "$($_.Name)-$($_.RemoteVersion)" `
            -releaseName $releaseName `
            -releaseDescription $packageDesc `
            -repository $repository `
            -headers $headers
    }

    $fileName = [System.IO.Path]::GetFileName($_.NuFile)

    $existing = $release.assets | ? name -eq $fileName
    if ($existing) {
        Write-Verbose "Removing existing $fileName asset..."
        Invoke-RestMethod -UseBasicParsing -Uri $existing.url -method Delete -Headers $headers | Out-Null
    }

    $uploadUrl = $release.upload_url -replace '\{.*\}$', ''
    $rawContent = [System.IO.File]::ReadAllBytes($_.NuFile)
    Write-Host "Uploading $fileName asset..."
    Invoke-RestMethod -UseBasicParsing -Uri "${uploadUrl}?name=${fileName}&label=$($_.Name) v$($_.RemoteVersion)" -Body $rawContent -Headers $uploadHeaders -Method Post | Out-Null
}
