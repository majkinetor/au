# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 06-Aug-2016.

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

    - Call your au_GetLatest function to get remote version. It will also set $nuspec_version.
    - If remote version is higher then the nuspec version:
        - Check the returned URLs and Versions for validity (unless NoCheckXXX variables are specified).
        - Download files and calculate the checksum, (unless Checksum is set to '').
        - Update the nuspec with the latest version.
        - Do the necessary file replacements.
        - Pack the files into the nuget package.

    You can also define au_BeforeUpdate and au_AfterUpdate functions to integrate your code into the
    update pipeline.
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

        return @{ URL = $url; Version = $version }
    }

    Update-Package
#>
function Update-Package {
    [CmdletBinding()]
    param(
        #Do not check URL and version for validity.
        [switch] $NoCheckUrl,

        #Do not check if latest returned version already exists in the Chocolatey repository.
        [switch] $NoCheckChocoVersion,

        #Specify checksum type, this requires elevation as AU will patch the choco Get-WebFile function temporarilly.
        [ValidateSet('all', 'x32', 'x64', '')]
        [string] $Checksum='all',

        #Timeout for all web operations. The default can be specified in global variable $global:au_timeout
        #If not specified at all it defaults to 100 seconds.
        [int]    $Timeout

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
            try
            {
                $response = request $url
                if ($response.ContentType -like '*text/html*') { $res = $false; $err="Latest $packageName URL content type is text/html" }
                else { $res = $true }
            }
            catch {
                $res = $false
                $err = $_
            }

            if (!$res) { throw "Can't validate latest $packageName URL '$url'`n$err" }
        }
    }

    function request( $url ) {
        if ([string]::IsNullOrWhiteSpace($url)) {throw 'The URL is empty'}
        $request = [System.Net.HttpWebRequest]::Create($url)
        if ($Timeout)  { $request.Timeout = $Timeout*1000 }
        $request.GetResponse()
    }

    function check_version() {
        $re = '^(\d+)(\.\d+){0,3}$'
        if ($Latest.Version -notmatch $re) { throw "Latest $packageName version doesn't match the pattern '$re': '$($Latest.Version)'" }
    }

    function updated() {
        #Updated only if nuspec version is lower then online version. That will allow to update package revision manually on package errors.
        [version]($latest_version) -gt [version]($nuspec_version)
    }

    function get_checksum() {
        "Determining checksum(s)"

        # Patch Get-WebFile
        $choco_tmp_path = "$Env:TEMP\chocolatey\au\chocolatey"
        rm -recurse -ea ignore $choco_tmp_path
        cp -recurse -force $Env:ChocolateyInstall\helpers $choco_tmp_path\helpers
        cp -recurse -force $Env:ChocolateyInstall\extensions $choco_tmp_path\extensions

        $fun_path = "$choco_tmp_path\helpers\functions\Get-WebFile.ps1"
        (gc $fun_path) -replace "^}", "  throw 'au_dummy'`n}" | sc $fun_path

        # Clear TMP
        $pkg_path = "$Env:TEMP\chocolatey\$packageName"
        Import-Module "$choco_tmp_path\helpers\chocolateyInstaller.psm1" -Force
        $env:chocolateyPackageName = "chocolatey\$packageName"

        if (('all','x64') -contains $Checksum) {
            $env:chocolateyForceX86 = ''
            try {
                rm -force -recurse -ea ignore $pkg_path
                .\tools\chocolateyInstall.ps1
            } catch {
                if ( "$_" -ne 'au_dummy') { throw $_ } else {
                    $item = gi $pkg_path\*
                    $global:Latest.Checksum64 = Get-FileHash $item | % Hash
                    "Package downloaded and hash calculated for 64x version"
                }
            }
        }

        if (('all','x32') -contains $Checksum) {
            $env:chocolateyForceX86 = 'true'
            try {
                rm -force -recurse -ea ignore $pkg_path
                .\tools\chocolateyInstall.ps1
            } catch {
                if ( "$_" -ne 'au_dummy') { throw $_ } else {
                    $item = gi $pkg_path\*
                    $global:Latest.Checksum32 = Get-FileHash $item | % Hash
                    "Package downloaded and hash calculated for 32x version"
                }
            }
        }
    }


    if (!$Timeout) { $Timeout = $global:au_timeout }
    if ($PSBoundParameters.Keys -notcontains 'NoCheckChocoVersion') { if ($global:NoCheckChocoVersion) { $NoCheckChocoVersion = $global:NoCheckChocoVersion } }
    if ($PSBoundParameters.Keys -notcontains 'NoCheckUrl') { if ($global:NoCheckUrl) { $NoCheckUrl = $global:NoCheckUrl } }

    $packageName = Split-Path $pwd -Leaf
    $nuspecFile = gi "$packageName.nuspec" -ea ig
    if (!$nuspecFile) {throw 'No nuspec file' }
    $nu = Load-NuspecFile
    $nuspec_version = $nu.package.metadata.version

    "$packageName - checking updates"
    try {
        $global:Latest = au_GetLatest
    } catch {
        throw "au_GetLatest failed`n$_"
    }
    $latest_version = $Latest.version

    if (!$NoCheckUrl) { check_url }
    check_version

    "nuspec version: $nuspec_version"
    "remote version: $latest_version"

    if (!(updated)) { 'No new version found'; return }

    if (!$NoCheckChocoVersion) {
        $choco_url = "https://chocolatey.org/packages/{0}/{1}" -f $packageName, $latest_version
        try {
            request $choco_url | out-null
            "New version is available but it already exists in chocolatey:`n  $choco_url"
            return
        } catch { }
    }

    'New version is available'

    if ($Checksum) { get_checksum }
  
    $sr = au_SearchReplace
    if (Test-Path Function:\au_BeforeUpdate) {
        'Running au_BeforeUpdate'
        au_BeforeUpdate
    }

    'Updating files'
    "  $(Split-Path $nuspecFile -Leaf)"
    "    updating version:  $nuspec_version -> $latest_version"
    $nu.package.metadata.version = "$latest_version"
    $nu.Save($nuspecFile)

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
    if (Test-Path Function:\au_AfterUpdate) {
        'Running au_AfterUpdate'
        au_AfterUpdate
    }
    return 'Package updated'
}

Set-Alias update Update-Package
