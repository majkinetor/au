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
        $download_page = Invoke-WebRequest -Uri https://github.com/hluk/CopyQ/releases

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
        $Include,

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
        $Latest.Keys | ? {$_ -like 'url*' } | % {
            $url = $Latest[ $_ ]
            if ($res = check_url $url) { throw "${res}:$url" } else { "  $url" | result }
        }
    }

    function get_checksum()
    {
        function invoke_installer() {
            if (!(Test-Path tools\chocolateyInstall.ps1)) { "  aborted, chocolateyInstall not found for this package" | result; return }

            Import-Module "$choco_tmp_path\helpers\chocolateyInstaller.psm1" -Force -Scope Global

            if ($ChecksumFor -eq 'none') { "Automatic checksum calculation is disabled"; return }
            if ($ChecksumFor -eq 'all')  { $arch = '32','64' } else { $arch = $ChecksumFor }

            $pkg_path = [System.IO.Path]::GetFullPath("$Env:TEMP\chocolatey\$($package.Name)\" + $global:Latest.Version) #https://github.com/majkinetor/au/issues/32
            mkdir -Force $pkg_path | Out-Null

            $Env:ChocolateyPackageName         = "chocolatey\$($package.Name)"
            $Env:ChocolateyPackageVersion      = $global:Latest.Version
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

                        $item = gi $filePath
                        $type = if ($global:Latest.ContainsKey('ChecksumType' + $a)) { $global:Latest.Item('ChecksumType' + $a) } else { 'sha256' }
                        $hash = (Get-FileHash $item -Algorithm $type | % Hash).ToLowerInvariant()

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
            Sleep -Milliseconds (Get-Random 500) #reduce probability multiple updateall threads entering here at the same time (#29)

            # Copy choco modules once a day
            if (Test-Path $choco_tmp_path) {
                $ct = gi $choco_tmp_path | % creationtime
                if (((get-date) - $ct).Days -gt 1) { rm -recurse -force $choco_tmp_path } else { Write-Verbose 'Chocolatey copy is recent, aborting monkey patching'; return }
            }

            Write-Verbose "Monkey patching chocolatey in: '$choco_tmp_path'"
            cp -recurse -force $Env:ChocolateyInstall\helpers $choco_tmp_path\helpers
            if (Test-Path $Env:ChocolateyInstall\extensions) { cp -recurse -force $Env:ChocolateyInstall\extensions $choco_tmp_path\extensions }

            $fun_path = "$choco_tmp_path\helpers\functions\Get-ChocolateyWebFile.ps1"
            (gc $fun_path) -replace '^\s+return \$fileFullPath\s*$', '  throw "au_break: $fileFullPath"' | sc $fun_path -ea ignore
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
        if (!(is_version $package.NuspecVersion)) {
            Write-Warning "Invalid nuspec file Version '$($package.NuspecVersion)' - using 0.0"
            $global:Latest.NuspecVersion = $package.NuspecVersion = '0.0'
        }
        if (!(is_version $Latest.Version)) { throw "Invalid version: $($Latest.Version)" }
        $package.RemoteVersion = $Latest.Version

        $Latest.NuspecVersion = [AUVersion] $Latest.NuspecVersion
        $Latest.Version = [AUVersion] $Latest.Version

        if (!$NoCheckUrl) { check_urls }

        "nuspec version: " + $package.NuspecVersion | result
        "remote version: " + $package.RemoteVersion | result

        $script:is_forced = $false
        if ($Latest.Version -gt $Latest.NuspecVersion) {
            if (!($NoCheckChocoVersion -or $Force)) {
                $choco_url = "https://chocolatey.org/packages/{0}/{1}" -f $global:Latest.PackageName, $package.RemoteVersion
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

        $match_url = ($Latest.Keys | ? { $_ -match '^URL*' } | select -First 1 | % { $Latest[$_] } | split-Path -Leaf) -match '(?<=\.)[^.]+$'
        if ($match_url -and !$Latest.FileType) { $Latest.FileType = $Matches[0] }

        if ($ChecksumFor -ne 'none') { get_checksum } else { 'Automatic checksum skipped' | result }

        if ($WhatIf) { $package.Backup() }
        try {
            if (Test-Path Function:\au_BeforeUpdate) { 'Running au_BeforeUpdate' | result; au_BeforeUpdate $package | result }
            if (!$NoReadme -and (Test-Path "$($package.Path)\README.md")) { Set-DescriptionFromReadme $package -SkipFirst 2 | result }        
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
            $global:Latest.Version = [AUVersion] $package.RemoteVersion
            $global:au_Version = $null
            return
        }

        $date_format = 'yyyyMMdd'
        $d = (get-date).ToString($date_format)
        $v = $Latest.NuspecVersion.Version
        $rev = $v.Revision.ToString()
        try { $revdate = [DateTime]::ParseExact($rev, $date_format,[System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None) } catch {}
        if (($rev -ne -1) -and !$revdate) { return }

        $build = if ($v.Build -eq -1) {0} else {$v.Build}
        $v = [version] ('{0}.{1}.{2}.{3}' -f $v.Major, $v.Minor, $build, $d)
        $package.RemoteVersion = [AUVersion]::new($v, $Latest.NuspecVersion.Prerelease, $Latest.NuspecVersion.BuildMetadata)
        $Latest.Version = $package.RemoteVersion
    }

    function set_latest( [HashTable]$latest, [string] $version ) {
        if (!$latest.PackageName) { $latest.PackageName = $package.Name }
        if (!$latest.NuspecVersion) { $latest.NuspecVersion = $version }
        $package.NuspecVersion = $latest.NuspecVersion
        $global:Latest = $latest
    }

    function update_files( [switch]$SkipNuspecFile )
    {
        'Updating files' | result
        '  $Latest data:' | result;  ($global:Latest.keys | sort | % { "    {0,-25} {1,-12} {2}" -f $_, "($($global:Latest[$_].GetType().Name))", $global:Latest[$_] }) | result

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
        }

        $sr = au_SearchReplace
        $sr.Keys | % {
            $fileName = $_
            "  $fileName" | result

            # If not specifying UTF8 encoding, then UTF8 without BOM encoded files
            # is detected as ANSI
            $fileContent = gc $fileName -Encoding UTF8
            $sr[ $fileName ].GetEnumerator() | % {
                ('    {0,-35} = {1}' -f $_.name, $_.value) | result
                if (!($fileContent -match $_.name)) { throw "Search pattern not found: '$($_.name)'" }
                $fileContent = $fileContent -replace $_.name, $_.value
            }

            $useBomEncoding = if ($fileName.EndsWith('.ps1')) { $true } else { $false }
            $encoding = New-Object System.Text.UTF8Encoding($useBomEncoding)
            $output = $fileContent | Out-String
            [System.IO.File]::WriteAllText((gi $fileName).FullName, $output, $encoding)
        }
    }

    function result() {
        if ($global:Silent) { return }

        $input | % {
            $package.Result += $_
            if (!$NoHostOutput) { Write-Host $_ }
        }
    }

    if ($PSCmdlet.MyInvocation.ScriptName -eq '') {
        Write-Verbose 'Running outside of the script'
        if (!(Test-Path update.ps1)) { return "Current directory doesn't contain ./update.ps1 script" } else { return ./update.ps1 }
    } else { Write-Verbose 'Running inside the script' }

    # Assign parameters from global variables with the prefix `au_` if they are bound
    (gcm $PSCmdlet.MyInvocation.InvocationName).Parameters.Keys | % {
        if ($PSBoundParameters.Keys -contains $_) { return }
        $value = gv "au_$_" -Scope Global -ea Ignore | % Value
        if ($value -ne $null) {
            sv $_ $value
            Write-Verbose "Parameter $_ set from global variable au_${_}: $value"
        }
    }

    if ($WhatIf) {  Write-Warning "WhatIf passed - package files will not be changed" }

    $package = [AUPackage]::new( $pwd )
    if ($Result) { sv -Scope Global -Name $Result -Value $package }

    [System.Net.ServicePointManager]::SecurityProtocol = 'Ssl3,Tls,Tls11,Tls12' #https://github.com/chocolatey/chocolatey-coreteampackages/issues/366
    $module = $MyInvocation.MyCommand.ScriptBlock.Module
    "{0} - checking updates using {1} version {2}" -f $package.Name, $module.Name, $module.Version | result
    try {
        $res = au_GetLatest | select -Last 1
        if ($res -eq $null) { throw 'au_GetLatest returned nothing' }

        if ($res -eq 'ignore') { return $res }

        $res_type = $res.GetType()
        if ($res_type -ne [HashTable]) { throw "au_GetLatest doesn't return a HashTable result but $res_type" }

        if ($global:au_Force) {
            $Force = $true
            if ($global:au_Include) { $Include = $global:au_Include }
        }
    } catch {
        throw "au_GetLatest failed`n$_"
    }

    if ($res.Streams) {
        if ($res.Streams -isnot [HashTable]) { throw "au_GetLatest's streams don't return a HashTable result but $($res.Streams.GetType())" }

        if ($Include) {
            if ($Include -isnot [string] -and $Include -isnot [Array]) { throw "`$Include must be either a String or an Array but is $($Include.GetType())" }
            if ($Include -is [string]) { [Array] $Include = $Include -split ',' | foreach { ,$_.Trim() } }
        } elseif ($Force) {
            $Include = @($res.Streams.Keys | sort { [AUVersion]$_ } -Descending | select -First 1)
        }
        if ($Force -and (!$Include -or $Include.Length -ne 1)) { throw 'A single stream must be included when forcing package update' }

        if ($Include) {
            $streams = @{}
            $res.Streams.Keys | ? { $_ -in $Include } | % {
                $streams.Add($_, $res.Streams[$_])
            }
        } else {
            $streams = $res.Streams
        }

        $streams.Keys | ? { !$Include -or $_ -in $Include } | sort { [AUVersion]$_ } | % {
            $stream = $streams[$_]

            '' | result
            "*** Stream: $_ ***" | result

            if ($stream -eq $null) { throw "au_GetLatest's $_ stream returned nothing" }
            if ($stream -eq 'ignore') { return }
            if ($stream -isnot [HashTable]) { throw "au_GetLatest's $_ stream doesn't return a HashTable result but $($stream.GetType())" }

            if ($package.Streams.$_ -eq 'ignore') {
                'Ignored' | result
                return
            }

            set_latest $stream $package.Streams.$_
            process_stream
        }

        $package.UpdateStreams($streams)
    } else {
        '' | result
        set_latest $res $package.NuspecVersion
        process_stream
    }

    if ($package.Updated) { 'Package updated' | result }

    return $package
}

Set-Alias update Update-Package
