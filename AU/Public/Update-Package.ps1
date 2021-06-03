# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 19-Dec-2016.

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

    - Call your au_GetLatest function to get the remote version and other information.
    - If remote version is higher then the nuspec version, function will:
        - Check the returned URLs, Versions and Checksums (if defined) for validity (unless NoCheckXXX variables are specified)
        - Download files and calculate checksum(s), (unless already defined or ChecksumFor is set to 'none')
        - Update the nuspec with the latest version
        - Do the necessary file replacements
        - Pack the files into the nuget package

    You can also define au_BeforeUpdate and au_AfterUpdate functions to integrate your code into the update pipeline.
.EXAMPLE
    PS> notepad update.ps1
    # The following script is used to update the package from the github releases page.
    # After it defines the 2 functions, it calls the Update-Package.
    # Checksums are automatically calculated for 32 bit version (the only one in this case)
    import-module au

    function global:au_SearchReplace {
        ".\tools\chocolateyInstall.ps1" = @{
            "(^[$]url32\s*=\s*)('.*')"          = "`$1'$($Latest.URL32)'"
            "(^[$]checksum32\s*=\s*)('.*')"     = "`$1'$($Latest.Checksum32)'"
            "(^[$]checksumType32\s*=\s*)('.*')" = "`$1'$($Latest.ChecksumType32)'"
        }
    }

    function global:au_GetLatest {
        $download_page = Invoke-WebRequest https://github.com/hluk/CopyQ/releases -UseBasicParsing

        $re  = "copyq-.*-setup.exe"
        $url = $download_page.links | ? href -match $re | select -First 1 -expand href
        $version = $url -split '-|.exe' | select -Last 1 -Skip 2

        return @{ URL32 = $url; Version = $version }
    }

    Update-Package -ChecksumFor 32

.NOTES
    All function parameters accept defaults via global variables with prefix `au_` (example: $global:au_Force = $true).

.OUTPUTS
    PSCustomObject with type AUPackage.

.LINK
    Update-AUPackages
#>
function Update-Package {
    [CmdletBinding()]
    param(
        #Do not check URL and version for validity.
        [switch] $NoCheckUrl,

        #Do not check if latest returned version already exists in the Chocolatey community feed.
        #Ignored when Force is specified.
        [switch] $NoCheckChocoVersion,

        #Specify for which architectures to calculate checksum - all, 32 bit, 64 bit or none.
        [ValidateSet('all', '32', '64', 'none')]
        [string] $ChecksumFor='all',

        #Timeout for all web operations, by default 100 seconds.
        [int]    $Timeout,

        #Streams to process, either a string or an array. If ommitted, all streams are processed.
        #Single stream required when Force is specified.
        $IncludeStream,

        #Force package update even if no new version is found.
        #For multi streams packages, most recent stream is checked by default when Force is specified.
        [switch] $Force,

        #Do not show any Write-Host output.
        [switch] $NoHostOutput,

        #Output variable.
        [string] $Result,

        #Backup and restore package.
        [switch] $WhatIf, 

        #Disable automatic update of nuspec description from README.md files with first 2 lines skipped.
        [switch] $NoReadme
    )

    function check_urls() {
        "URL check" | result
        $Latest.Keys | Where-Object {$_ -like 'url*' } | ForEach-Object {
            $url = $Latest[ $_ ]
            if ($res = check_url $url -Options $Latest.Options) { throw "${res}:$url" } else { "  $url" | result }
        }
    }

    function get_checksum()
    {
        function invoke_installer() {
            if (!(Test-Path tools\chocolateyInstall.ps1)) { "  aborted, chocolateyInstall not found for this package" | result; return }

            Import-Module "$choco_tmp_path\helpers\chocolateyInstaller.psm1" -Force -Scope Global

            if ($ChecksumFor -eq 'none') { "Automatic checksum calculation is disabled"; return }
            if ($ChecksumFor -eq 'all')  { $arch = '32','64' } else { $arch = $ChecksumFor }

            $Env:ChocolateyPackageFolder = [System.IO.Path]::GetFullPath("$Env:TEMP\chocolatey\$($package.Name)") #https://github.com/majkinetor/au/issues/32
            $pkg_path = Join-Path $Env:ChocolateyPackageFolder $global:Latest.Version
            New-Item -Type Directory -Force $pkg_path | Out-Null

            $Env:ChocolateyPackageName         = "chocolatey\$($package.Name)"
            $Env:ChocolateyPackageVersion      = $global:Latest.Version.ToString()
            $Env:ChocolateyAllowEmptyChecksums = 'true'
            foreach ($a in $arch) {
                $Env:chocolateyForceX86 = if ($a -eq '32') { 'true' } else { '' }
                try {
                    #rm -force -recurse -ea ignore $pkg_path
                    .\tools\chocolateyInstall.ps1 | result
                } catch {
                    if ( "$_" -notlike 'au_break: *') { throw $_ } else {
                        $filePath = "$_" -replace 'au_break: '
                        if (!(Test-Path $filePath)) { throw "Can't find file path to checksum" }

                        $item = Get-Item $filePath
                        $type = if ($global:Latest.ContainsKey('ChecksumType' + $a)) { $global:Latest.Item('ChecksumType' + $a) } else { 'sha256' }
                        $hash = (Get-FileHash $item -Algorithm $type | ForEach-Object Hash).ToLowerInvariant()

                        if (!$global:Latest.ContainsKey('ChecksumType' + $a)) { $global:Latest.Add('ChecksumType' + $a, $type) }
                        if (!$global:Latest.ContainsKey('Checksum' + $a)) {
                            $global:Latest.Add('Checksum' + $a, $hash)
                            "Package downloaded and hash calculated for $a bit version" | result
                        } else {
                            $expected = $global:Latest.Item('Checksum' + $a)
                            if ($hash -ne $expected) { throw "Hash for $a bit version mismatch: actual = '$hash', expected = '$expected'" }
                            "Package downloaded and hash checked for $a bit version" | result
                        }
                    }
                }
            }
        }

        function fix_choco {
            Start-Sleep -Milliseconds (Get-Random 500) #reduce probability multiple updateall threads entering here at the same time (#29)

            # Copy choco modules once a day
            if (Test-Path $choco_tmp_path) {
                $ct = Get-Item $choco_tmp_path | ForEach-Object creationtime
                if (((get-date) - $ct).Days -gt 1) { Remove-Item -recurse -force $choco_tmp_path } else { Write-Verbose 'Chocolatey copy is recent, aborting monkey patching'; return }
            }

            Write-Verbose "Monkey patching chocolatey in: '$choco_tmp_path'"
            Copy-Item -recurse -force $Env:ChocolateyInstall\helpers $choco_tmp_path\helpers
            if (Test-Path $Env:ChocolateyInstall\extensions) { Copy-Item -recurse -force $Env:ChocolateyInstall\extensions $choco_tmp_path\extensions }

            $fun_path = "$choco_tmp_path\helpers\functions\Get-ChocolateyWebFile.ps1"
            (Get-Content $fun_path) -replace '^\s+return \$fileFullPath\s*$', '  throw "au_break: $fileFullPath"' | Set-Content $fun_path -ea ignore
        }

        "Automatic checksum started" | result

        # Copy choco powershell functions to TEMP dir and monkey patch the Get-ChocolateyWebFile function
        $choco_tmp_path = "$Env:TEMP\chocolatey\au\chocolatey"
        fix_choco

        # This will set the new URLs before the files are downloaded but will replace checksums to empty ones so download will not fail
        #  because checksums are at that moment set for the previous version.
        # SkipNuspecFile is passed so that if things fail here, nuspec file isn't updated; otherwise, on next run
        #  AU will think that package is the most recent. 
        #
        # TODO: This will also leaves other then nuspec files updated which is undesired side effect (should be very rare)
        #
        $global:Silent = $true

        $c32 = $global:Latest.Checksum32; $c64 = $global:Latest.Checksum64          #https://github.com/majkinetor/au/issues/36
        $global:Latest.Remove('Checksum32'); $global:Latest.Remove('Checksum64')    #  -||-
        update_files -SkipNuspecFile | out-null
        if ($c32) {$global:Latest.Checksum32 = $c32}
        if ($c64) {$global:Latest.Checksum64 = $c64}                                #https://github.com/majkinetor/au/issues/36

        $global:Silent = $false

        # Invoke installer for each architecture to download files
        invoke_installer
    }

    function process_stream() {
        $package.Updated = $false

        if (!(is_version $package.NuspecVersion)) {
            Write-Warning "Invalid nuspec file Version '$($package.NuspecVersion)' - using 0.0"
            $global:Latest.NuspecVersion = $package.NuspecVersion = '0.0'
        }
        if (!(is_version $Latest.Version)) { throw "Invalid version: $($Latest.Version)" }
        $package.RemoteVersion = $Latest.Version

        # For set_fix_version to work propertly, $Latest.Version's type must be assignable from string.
        # If not, then cast its value to string.
        if (!('1.0' -as $Latest.Version.GetType())) {
            $Latest.Version = [string] $Latest.Version
        }

        if (!$NoCheckUrl) { check_urls }

        "nuspec version: " + $package.NuspecVersion | result
        "remote version: " + $package.RemoteVersion | result

        $script:is_forced = $false
        if ([AUVersion] $Latest.Version -gt [AUVersion] $Latest.NuspecVersion) {
            if (!($NoCheckChocoVersion -or $Force)) {
                if ( !$au_GalleryUrl ) { $au_GalleryUrl = 'https://chocolatey.org' } 
                $choco_url = "$au_GalleryUrl/packages/{0}/{1}" -f $global:Latest.PackageName, $package.RemoteVersion
                try {
                    request $choco_url $Timeout | out-null
                    "New version is available but it already exists in the Chocolatey community feed (disable using `$NoCheckChocoVersion`):`n  $choco_url" | result
                    return
                } catch { }
            }
        } else {
            if (!$Force) {
                'No new version found' | result
                return
            }
            else { 'No new version found, but update is forced' | result; set_fix_version }
        }

        'New version is available' | result

        $match_url = ($Latest.Keys | Where-Object { $_ -match '^URL*' } | Select-Object -First 1 | ForEach-Object { $Latest[$_] } | split-Path -Leaf) -match '(?<=\.)[^.]+$'
        if ($match_url -and !$Latest.FileType) { $Latest.FileType = $Matches[0] }

        if ($ChecksumFor -ne 'none') { get_checksum } else { 'Automatic checksum skipped' | result }

        if ($WhatIf) { $package.Backup() }
        try {
            if (Test-Path Function:\au_BeforeUpdate) { 'Running au_BeforeUpdate' | result; au_BeforeUpdate $package | result }
            if (!$NoReadme -and (Test-Path (Join-Path $package.Path 'README.md'))) { Set-DescriptionFromReadme $package -SkipFirst 2 | result }        
            update_files
            if (Test-Path Function:\au_AfterUpdate) { 'Running au_AfterUpdate' | result; au_AfterUpdate $package | result }
        
            choco pack --limit-output | result
            if ($LastExitCode -ne 0) { throw "Choco pack failed with exit code $LastExitCode" }
        } finally {
            if ($WhatIf) {
                $save_dir = $package.SaveAndRestore() 
                Write-Warning "Package restored and updates saved to: $save_dir"
            }
        }

        $package.Updated = $true
    }

    function set_fix_version() {
        $script:is_forced = $true

        if ($global:au_Version) {
            "Overriding version to: $global:au_Version" | result
            $package.RemoteVersion = $global:au_Version
            if (!(is_version $global:au_Version)) { throw "Invalid version: $global:au_Version" }
            $global:Latest.Version = $package.RemoteVersion
            $global:au_Version = $null
            return
        }

        $date_format = 'yyyyMMdd'
        $d = (get-date).ToString($date_format)
        $nuspecVersion = [AUVersion] $Latest.NuspecVersion
        $v = $nuspecVersion.Version
        $rev = $v.Revision.ToString()
        try { $revdate = [DateTime]::ParseExact($rev, $date_format,[System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None) } catch {}
        if (($rev -ne -1) -and !$revdate) { return }

        $build = if ($v.Build -eq -1) {0} else {$v.Build}
        $v = [version] ('{0}.{1}.{2}.{3}' -f $v.Major, $v.Minor, $build, $d)
        $package.RemoteVersion = $nuspecVersion.WithVersion($v).ToString()
        $Latest.Version = $package.RemoteVersion -as $Latest.Version.GetType()
    }

    function set_latest( [HashTable] $latest, [string] $version, $stream ) {
        if (!$latest.NuspecVersion) { $latest.NuspecVersion = $version }
        if ($stream -and !$latest.Stream) { $latest.Stream = $stream }
        $package.NuspecVersion = $latest.NuspecVersion

        $global:Latest = $global:au_Latest
        $latest.Keys | ForEach-Object { $global:Latest.Remove($_) }
        $global:Latest += $latest
    }

    function update_files( [switch]$SkipNuspecFile )
    {
        'Updating files' | result
        '  $Latest data:' | result;  ($global:Latest.keys | Sort-Object | ForEach-Object { $v=$global:Latest[$_]; "    {0,-25} {1,-12} {2}" -f $_, "($( if ($v) { $v.GetType().Name } ))", $v }) | result

        if (!$SkipNuspecFile) {
            "  $(Split-Path $package.NuspecPath -Leaf)" | result

            "    setting id: $($global:Latest.PackageName)" | result
            $package.NuspecXml.package.metadata.id = $package.Name = $global:Latest.PackageName.ToString()

            $msg = "    updating version: {0} -> {1}" -f $package.NuspecVersion, $package.RemoteVersion
            if ($script:is_forced) {
                if ($package.RemoteVersion -eq $package.NuspecVersion) {
                    $msg = "    version not changed as it already uses 'revision': {0}" -f $package.NuspecVersion
                } else {
                    $msg = "    using Chocolatey fix notation: {0} -> {1}" -f $package.NuspecVersion, $package.RemoteVersion
                }
            }
            $msg | result

            $package.NuspecXml.package.metadata.version = $package.RemoteVersion.ToString()
            $package.SaveNuspec()
            if ($global:Latest.Stream) {
                $package.UpdateStream($global:Latest.Stream, $package.RemoteVersion)
            }
        }

        $sr = au_SearchReplace
        $sr.Keys | ForEach-Object {
            $fileName = $_
            "  $fileName" | result

            # If not specifying UTF8 encoding, then UTF8 without BOM encoded files
            # is detected as ANSI
            $fileContent = Get-Content $fileName -Encoding UTF8
            $sr[ $fileName ].GetEnumerator() | ForEach-Object {
                ('    {0,-35} = {1}' -f $_.name, $_.value) | result
                if (!($fileContent -match $_.name)) { throw "Search pattern not found: '$($_.name)'" }
                $fileContent = $fileContent -replace $_.name, $_.value
            }

            $useBomEncoding = if ($fileName.EndsWith('.ps1')) { $true } else { $false }
            $encoding = New-Object System.Text.UTF8Encoding($useBomEncoding)
            $output = $fileContent | Out-String
            [System.IO.File]::WriteAllText((Get-Item $fileName).FullName, $output, $encoding)
        }
    }

    function result() {
        if ($global:Silent) { return }

        $input | ForEach-Object {
            $package.Result += $_
            if (!$NoHostOutput) { Write-Host $_ }
        }
    }

    if ($PSCmdlet.MyInvocation.ScriptName -eq '') {
        Write-Verbose 'Running outside of the script'
        if (!(Test-Path update.ps1)) { return "Current directory doesn't contain ./update.ps1 script" } else { return ./update.ps1 }
    } else { Write-Verbose 'Running inside the script' }

    # Assign parameters from global variables with the prefix `au_` if they are bound
    (Get-Command $PSCmdlet.MyInvocation.InvocationName).Parameters.Keys | ForEach-Object {
        if ($PSBoundParameters.Keys -contains $_) { return }
        $value = Get-Variable "au_$_" -Scope Global -ea Ignore | ForEach-Object Value
        if ($value -ne $null) {
            Set-Variable $_ $value
            Write-Verbose "Parameter $_ set from global variable au_${_}: $value"
        }
    }

    if ($WhatIf) {  Write-Warning "WhatIf passed - package files will not be changed" }

    $package = [AUPackage]::new( $pwd )
    if ($Result) { Set-Variable -Scope Global -Name $Result -Value $package }

    $global:Latest = @{PackageName = $package.Name}

    if ($PSVersionTable.PSVersion.major -ge 6) {
        $AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -ge 'Tls' } # PowerShell 6+ does not support SSL3, so use TLS minimum
    } else {
        # https://github.com/majkinetor/au/issues/206
        $AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') # This way we do not try to add something that is not supported on every version of Windows like Tls13
        #$AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -ge 'Tls' } If we want to enforce a minimum version
    }

    $AvailableTls.ForEach({[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $_})
    

    
    $module = $MyInvocation.MyCommand.ScriptBlock.Module
    "{0} - checking updates using {1} version {2}" -f $package.Name, $module.Name, $module.Version | result
    try {
        $res = au_GetLatest | Select-Object -Last 1
        $global:au_Latest = $global:Latest
        if ($res -eq $null) { throw 'au_GetLatest returned nothing' }

        if ($res -eq 'ignore') { return $res }

        $res_type = $res.GetType()
        if ($res_type -ne [HashTable]) { throw "au_GetLatest doesn't return a HashTable result but $res_type" }

        if ($global:au_Force) { $Force = $true }
        if ($global:au_IncludeStream) { $IncludeStream = $global:au_IncludeStream }
    } catch {
        throw "au_GetLatest failed`n$_"
    }

    if ($res.ContainsKey('Streams')) {
        if (!$res.Streams) { throw "au_GetLatest's streams returned nothing" }
        if ($res.Streams -isnot [System.Collections.Specialized.OrderedDictionary] -and $res.Streams -isnot [HashTable]) {
            throw "au_GetLatest doesn't return an OrderedDictionary or HashTable result for streams but $($res.Streams.GetType())"
        }

        # Streams are expected to be sorted starting with the most recent one
        $streams = @($res.Streams.Keys)
        # In case of HashTable (i.e. not sorted), let's sort streams alphabetically descending
        if ($res.Streams -is [HashTable]) { $streams = $streams | Sort-Object -Descending }

        if ($IncludeStream) {
            if ($IncludeStream -isnot [string] -and $IncludeStream -isnot [double] -and $IncludeStream -isnot [Array]) {
                throw "`$IncludeStream must be either a String, a Double or an Array but is $($IncludeStream.GetType())"
            }
            if ($IncludeStream -is [double]) { $IncludeStream = $IncludeStream -as [string] }
            if ($IncludeStream -is [string]) { 
                # Forcing type in order to handle case when only one version is included
                [Array] $IncludeStream = $IncludeStream -split ',' | ForEach-Object { $_.Trim() }
            }
        } elseif ($Force) {
            # When forcing update, a single stream is expected
            # By default, we take the first one (i.e. the most recent one)
            $IncludeStream = @($streams | Select-Object -First 1)
        }
        if ($Force -and (!$IncludeStream -or $IncludeStream.Length -ne 1)) { throw 'A single stream must be included when forcing package update' }

        if ($IncludeStream) { $streams = @($streams | Where-Object { $_ -in $IncludeStream }) }
        # Let's reverse the order in order to process streams starting with the oldest one
        [Array]::Reverse($streams)

        $res.Keys | Where-Object { $_ -ne 'Streams' } | ForEach-Object { $global:au_Latest.Remove($_) }
        $global:au_Latest += $res

        $allStreams = [System.Collections.Specialized.OrderedDictionary] @{}
        $streams | ForEach-Object {
            $stream = $res.Streams[$_]

            '' | result
            "*** Stream: $_ ***" | result

            if ($stream -eq $null) { throw "au_GetLatest's $_ stream returned nothing" }
            if ($stream -eq 'ignore') {
                $stream | result
                return
            }
            if ($stream -isnot [HashTable]) { throw "au_GetLatest's $_ stream doesn't return a HashTable result but $($stream.GetType())" }

            if ($package.Streams.$_.NuspecVersion -eq 'ignore') {
                'Ignored' | result
                return
            }

            set_latest $stream $package.Streams.$_.NuspecVersion $_
            process_stream

            $allStreams.$_ = if ($package.Streams.$_) { $package.Streams.$_.Clone() } else { @{} }
            $allStreams.$_.NuspecVersion = $package.NuspecVersion
            $allStreams.$_ += $package.GetStreamDetails()
        }
        $package.Updated = $false
        $package.Streams = $allStreams
        $package.Streams.Values | Where-Object { $_.Updated } | ForEach-Object {
            $package.NuspecVersion = $_.NuspecVersion
            $package.RemoteVersion = $_.RemoteVersion
            $package.Updated = $true
        }
    } else {
        '' | result
        set_latest $res $package.NuspecVersion
        process_stream
    }

    if ($package.Updated) {
        '' | result
        'Package updated' | result
    }

    return $package
}

Set-Alias update Update-Package
