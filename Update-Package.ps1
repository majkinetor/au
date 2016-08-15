# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 15-Aug-2016.

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
        - Check the returned URLs, Versions and Checksums (if defined) for validity (unless NoCheckXXX variables are specified).
        - Download files and calculate the checksum, (unless already defined or ChecksumFor is set to 'none').
        - Update the nuspec with the latest version.
        - Do the necessary file replacements.
        - Pack the files into the nuget package.

    You can also define au_BeforeUpdate and au_AfterUpdate functions to integrate your code into the
    update pipeline.
.EXAMPLE
    PS> notepad update.ps1
    # The following script is used to update the package from the github releases page.
    # Once it defines the 2 functions, it calls the Update-Package.
    # Checksums are automatically calculated for 32 bit version (the only one in this case)
    import-module au

    function global:au_SearchReplace {
        ".\tools\chocolateyInstall.ps1" = @{
            "(^[$]url32\s*=\s*)('.*')"      = "`$1'$($Latest.URL32)'"
            "(^[$]checksum32\s*=\s*)('.*')" = "`$1'$($Latest.Checksum32)'"
            "(^[$]checksumType32\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType32)'"
        }
    }

    function global:au_GetLatest {
        $download_page = Invoke-WebRequest -Uri https://github.com/hluk/CopyQ/releases

        $re  = "copyq-.*-setup.exe"
        $url = $download_page.links | ? href -match $re | select -First 1 -expand href
        $version = $url -split '-|.exe' | select -Last 1 -Skip 2

        return @{ URL32 = $url; Version = $version }
    }

    Update-Package -ChecksumFor 32
#>
function Update-Package {
    [CmdletBinding()]
    param(
        #Do not check URL and version for validity.
        #Defaults to global variable $au_NoCheckUrl if not specified.
        [switch] $NoCheckUrl,

        #Do not check if latest returned version already exists in the Chocolatey repository.
        #Defaults to global variable $au_NoCheckChocoVersion if not specified.
        #Ignored when Force is specified.
        [switch] $NoCheckChocoVersion,

        #Specify for which architectures to calculate checksum - all, 32 bit, 64 bit or none.
        #Defaults to global variable $au_ChecksumFor if not specified.
        [ValidateSet('all', '32', '64', 'none')]
        [string] $ChecksumFor='all',

        #Timeout for all web operations.
        #Defaults to global variable $au_Timeout if not specified.
        #If not specified at all it defaults to 100 seconds.
        [int]    $Timeout,

        #Force package update even if no new version is found. This is useful for troubleshooting and updating checksums etc.
        #Defaults to global variable $au_Force if not specified.
        [switch] $Force
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

            if (!$res) { throw "Can't validate latest $packageName URL (disable using `$NoCheckUrl) '$url'`n$err" }
        }
    }

    function request( $url ) {
        if ([string]::IsNullOrWhiteSpace($url)) {throw 'The URL is empty'}
        $request = [System.Net.WebRequest]::Create($url)
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

    function get_checksum()
    {
        function invoke_installer() {
            if (!(Test-Path tools\chocolateyInstall.ps1)) { return }

            Import-Module "$choco_tmp_path\helpers\chocolateyInstaller.psm1" -Force
            $env:chocolateyPackageName = "chocolatey\$packageName"

            if ($ChecksumFor -eq 'none') { "Automatic checksum calculation is disabled"; return }
            if ($ChecksumFor -eq 'all')  { $arch = '32','64' } else { $arch = $ChecksumFor }

            $pkg_path = "$Env:TEMP\chocolatey\$packageName\" + $global:Latest.Version
            $env:ChocolateyPackageVersion = $global:Latest.Version
            $env:ChocolateyAllowEmptyChecksums = 'true'
            foreach ($a in $arch) {
                $Env:chocolateyForceX86 = if ($a -eq '32') { 'true' } else { '' }
                try {
                    rm -force -recurse -ea ignore $pkg_path
                    .\tools\chocolateyInstall.ps1
                } catch {
                    if ( "$_" -notlike 'au_break: *') { throw $_ } else {
                        $filePath = "$_" -replace 'au_break: '
                        if (!(Test-Path $filePath)) { throw "Can't find file path to checksum" }

                        $item = gi $filePath
                        $type = if ($global:Latest.ContainsKey('ChecksumType' + $a)) { $global:Latest.Item('ChecksumType' + $a) } else { 'sha256' }
                        $hash = (Get-FileHash $item -Algorithm $type | % Hash).ToLowerInvariant()

                        if (!$global:Latest.ContainsKey('ChecksumType' + $a)) { $global:Latest.Add('ChecksumType' + $a, $type) }
                        if (!$global:Latest.ContainsKey('Checksum' + $a)) {
                            $global:Latest.Add('Checksum' + $a, $hash)
                            "Package downloaded and hash calculated for $a bit version"
                        } else {
                            $expected = $global:Latest.Item('Checksum' + $a)
                            if ($hash -ne $expected) { throw "Hash for $a bit version mismatch: actual = '$hash', expected = '$expected'" }
                            "Package downloaded and hash checked for $a bit version"
                        }
                    }
                }
            }
        }

        function fix_choco {
            # Copy choco modules once a day
            if (Test-Path $choco_tmp_path) {
                $ct = gi $choco_tmp_path | % creationtime
                if (((get-date) - $ct).Days -gt 1) { rm -recurse -force $choco_tmp_path } else { return }
            }
            Write-Verbose "Monkey patching chocolatey in: '$choco_tmp_path'"
            cp -recurse -force $Env:ChocolateyInstall\helpers $choco_tmp_path\helpers
            if (Test-Path $Env:ChocolateyInstall\extensions) { cp -recurse -force $Env:ChocolateyInstall\extensions $choco_tmp_path\extensions }

            $fun_path = "$choco_tmp_path\helpers\functions\Get-ChocolateyWebFile.ps1"
            (gc $fun_path) -replace '^\s+return \$fileFullPath\s*$', '  throw "au_break: $fileFullPath"' | sc $fun_path
        }

        "Automatic checksum started"

        # Copy choco powershell functions to TEMP dir and monkey patch the Get-ChocolateyWebFile function
        $choco_tmp_path = "$Env:TEMP\chocolatey\au\chocolatey"
        fix_choco

        # This will set the new URLS before the files are downloaded but will replace checksums to empty ones so download will not fail
        #  because those still contain the checksums for the previous version.
        # SkipNuspecFile is passed so that if things fail here, nuspec file isn't updated; otherwise, on next run
        #  AU will think that package is most recent
        #
        update_files -SkipNuspecFile | out-null

        # Invoke installer for each architecture to download files
        invoke_installer
    }

    function update_files( [switch]$SkipNuspecFile )
    {
        'Updating files'

        if (!$SkipNuspecFile) {
            "  $(Split-Path $nuspecFile -Leaf)"

            if (updated) {
                "    updating version:  $nuspec_version -> $latest_version"
            } else {
                $d = (get-date).ToString('yyyyMMdd')
                $v = [version]$nuspec_version
                $rev = $v.Revision.ToString()
                try { $revdate = [DateTime]::ParseExact($rev, 'yyyyMMdd',[System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None) } catch {}
                if ($rev -eq -1 -or $revdate) {
                    $build = if ($v.Build -eq -1) {0} else {$v.Build}
                    $latest_version = '{0}.{1}.{2}.{3}' -f $v.Major, $v.Minor, $build, $d
                    "    updating version using Chocolatey fix notation: $nuspec_version -> $latest_version"
                } else {
                    $latest_version = "$v"
                    "    version not changed as it already uses 'revision': $latest_version"
                }
            }
            $nu.package.metadata.id = "$packageName"
            $nu.package.metadata.version = "$latest_version"
            $nu.Save($nuspecFile)
        }

        $sr = au_SearchReplace
        $sr.Keys | % {
            $fileName = $_
            "  $fileName"

            $fileContent = gc $fileName
            $sr[ $fileName ].GetEnumerator() | % {
                ('    {0} = {1} ' -f $_.name, $_.value)
                if (!($fileContent -match $_.name)) { throw "Search pattern not found: '$($_.name)'" }
                $fileContent = $fileContent -replace $_.name, $_.value
            }

            $fileContent | Out-File -Encoding UTF8 $fileName
        }
    }

    if ($PSBoundParameters.Keys -notcontains 'Timeout')             { if ($global:au_Timeout) { $Timeout = $global:au_Timeout } }
    if ($PSBoundParameters.Keys -notcontains 'NoCheckChocoVersion') { if ($global:au_NoCheckChocoVersion) { $NoCheckChocoVersion = $global:au_NoCheckChocoVersion } }
    if ($PSBoundParameters.Keys -notcontains 'NoCheckUrl')          { if ($global:au_NoCheckUrl) { $NoCheckUrl = $global:au_NoCheckUrl } }
    if ($PSBoundParameters.Keys -notcontains 'Force')               { if ($global:au_Force) { $Force = $global:au_Force } }
    if ($PSBoundParameters.Keys -notcontains 'ChecksumFor')         { if ($global:au_ChecksumFor) { $ChecksumFor = $global:au_ChecksumFor } }

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

    if (!(updated)) {
        if (!$Force) { 'No new version found'; return }
        else { 'No new version found, but update is forced' }
    }

    if (!($NoCheckChocoVersion -or $Force)) {
        $choco_url = "https://chocolatey.org/packages/{0}/{1}" -f $packageName, $latest_version
        try {
            request $choco_url | out-null
            "New version is available but it already exists in chocolatey (disable using `$NoCheckChocoVersion):`n  $choco_url"
            return
        } catch { }
    }

    if (updated) { 'New version is available' }

    $global:Latest.Add('PackageName', $packageName)

    if ($ChecksumFor -ne 'none') { get_checksum }

    if (Test-Path Function:\au_BeforeUpdate) { 'Running au_BeforeUpdate'; au_BeforeUpdate }
    update_files
    if (Test-Path Function:\au_AfterUpdate) { 'Running au_AfterUpdate'; au_AfterUpdate }

    choco pack
    return 'Package updated'
}

Set-Alias update Update-Package
