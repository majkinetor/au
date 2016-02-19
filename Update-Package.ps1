# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 19-Feb-2016.

<#
.SYNOPSIS
    Update automatic package

.DESCRIPTION
    This function is used to perform necessary updates to the specified files in the package.
    It shouldn't be used on its own but must be part of the script which defines two functions:

    - au_SearchReplace
      The function should return HashTable where keys are file paths and value is another HashTable
      where keys and values are standard search and replace strings
    - au_GetLatest
      Returns the HashTable where the script specifies information about new Version, new URLs and
      any other data. You can refer to this variable as the $Latest in the script.
      While Version is used to determine if updates to the package are needed, other arguments can
      be used in search and replace patterns or for whatever purpose.

    With those 2 functions defined, calling Update-Package will:

    - Update the nuspec with the latest version
    - Do the necessary file replacements
    - Check the returned URLs and Versions for validity (unless NoCheck is specified)
    - Pack the files into the nuget package
.EXAMPLE
    PS> notepad update.ps1
    # The following script is used to update the package from the github releases page.
    # Once it defines the 2 functions, it calls the Update-Package.
    import-module au

    function global:au_SearchReplace {
        @{".\tools\chocolateyInstall.ps1" = @{ "(^[$]url\s*=\s*)('.*')" = "`$1'$($Latest.URL)'" }}
    }

    function global:au_GetLatest {
        $download_page = Invoke-WebRequest -Uri https://github.com/hluk/CopyQ/releases

        $re  = "copyq-.*-setup.exe"
        $url = $download_page.links | ? href -match $re | select -First 1 -expand href
        $version = $url -split '-|.exe' | select -Last 1 -Skip 2

        return $Latest = @{ URL = $url; Version = $version }
    }

    Update-Package
#>
function Update-Package {
    [CmdletBinding()]
    param(
        #Do not check URL and version
        [switch] $NoCheck
    )

    function Load-NuspecFile() {
        $nu = New-Object xml
        $nu.psbase.PreserveWhitespace = $true
        $nu.Load($nuspecFile)
        $nu
    }

    function check_url() {
        $Latest.Keys | ? {$_ -like 'url*' } | % {
            $url = $Latest[ $_ ]
            if ([string]::IsNullOrWhiteSpace($url)) {throw 'URL is empty'}
            try
            {
                $request  = [System.Net.HttpWebRequest]::Create($url)
                $request.Timeout = 5000
                $response = $request.GetResponse()
                if ($response.ContentType -like '*text/html*') { $res = $false; $err='Invalid content type: text/html' }
                else { $res = $true }
            }
            catch {
                $res = $false
                $err = $_
            }

            if (!$res) { throw "Can't validate URL '$url'`n$err" }
        }
    }

    function check_version() {
        $re = '^[\d.]+$'
        if ($Latest.Version -notmatch $re) { throw "Version doesn't match the pattern '$re': '$Version'" }
    }

    function check() { check_url; check_version}

    $packageName = Split-Path $pwd -Leaf
    $nuspecFile = gi "$packageName.nuspec" -ea ig
    if (!$nuspecFile) {throw 'No nuspec file' }
    $nu = Load-NuspecFile
    $global:nuspec_version = $nu.package.metadata.version

    "$packageName - checking updates"
    try {
        $global:Latest  = au_GetLatest
    } catch {
        throw "au_GetLatest failed`n$_"
    }
    $latest_version = $Latest.version

    if (!$NoCheck) { check }

    "nuspec version: $nuspec_version"
    "remote version: $latest_version"

    if ($latest_version -eq $nuspec_version) {
        return 'No new version found'
    } else { 'New version is available, updating' }

    'Updating files'
    "  $(Split-Path $nuspecFile -Leaf)"
    "    updating version:  $nuspec_version -> $latest_version"
    $nu.package.metadata.version = "$latest_version"
    $nu.Save($nuspecFile)

    $sr = au_SearchReplace
    $sr.Keys | % {
        $fileName = $_
        "  $fileName"

        $fileContent = gc $fileName
        $sr[ $fileName ].GetEnumerator() | % {
            ('    {0} = {1} ' -f $_.name, $_.value)
            $fileContent = $fileContent -replace $_.name, $_.value
        }

        $fileContent | Out-File -Encoding UTF8 $fileName
    }

    cpack
    return 'Package updated'
}

Set-Alias update Update-Package