# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 20-Dec-2016.

<#
.SYNOPSIS
   Get Latest URL32 and/or URL64 into tools directxory.

.DESCRIPTION
   This function will download the binaries pointed to by $Latest.URL32 and $Latest.URL34.
   The function is used to embed binaries into the Chocolatey package.

   The function will keep original remote file name but it will add suffix _x32 or _x64.
   This is intentional because you can use those to match particular installer via wildcards,
   e.g. `gi *_x32.exe`.

#>
function Get-RemoteFiles {
    param (
        # Delete existing file having $Latest.FileType extension.
        # Otherwise, when state of the package remains after the update, older installers
        # will pile up and may get included in the updated package.
        [switch] $Purge,

        # Override remote file name, use this one as a base. Suffixes _x32/_x64 are added.
        # Use this parameter if remote URL doesn't contain file name but generated hash.
        [string] $FileNameBase,

        # By default last URL part is used as a file name. Use this paramter to skip parts 
        # if file name is specified earlier in the path.
        [int]    $FileNameSkip=0,

        # Sets the algorithm to use when calculating checksums
        # This defaults to sha256
        [ValidateSet('md5','sha1','sha256','sha384','sha512')]
        [string] $Algorithm = 'sha256'
    )

    function name4url($url) {
        if ($FileNameBase) { return $FileNameBase }
        $res = $url -split '/' | select -Last 1 -Skip $FileNameSkip
        $res -replace '\.[a-zA-Z]+$'
    }

    function ext() {
        if ($Latest.FileType) { return $Latest.FileType }
        $url = $Latest.Url32; if (!$url) { $url = $Latest.Url64 }
        if ($url -match '(?<=\.)[^.]+$') { return $Matches[0] }
    }

    $toolsPath = Resolve-Path tools
    $ext = ext
    if (!$ext) { throw 'Unknown file type' }

    if ($Purge) {
        Write-Host 'Purging' $ext
        rm -Force "$toolsPath\*.$ext" -ea ignore
    }

    try {
        $client = New-Object System.Net.WebClient

        if ($Latest.Url32) {
            $base_name = name4url $Latest.Url32
            $file_name = "{0}_x32.{1}" -f $base_name, $ext
            $file_path = "$toolsPath\$file_name"

            Write-Host "Downloading to $file_name -" $Latest.Url32
            $client.DownloadFile($Latest.URL32, $file_path)
            $global:Latest.Checksum32 = Get-FileHash $file_path -Algorithm $Algorithm | % Hash
            $global:Latest.ChecksumType32 = $Algorithm
            $global:Latest.FileName32 = $file_name
        }

        if ($Latest.Url64) {
            $base_name = name4url $Latest.Url64
            $file_name = "{0}_x64.{1}" -f $base_name, $ext
            $file_path = "$toolsPath\$file_name"

            Write-Host "Downloading to $file_name -" $Latest.Url64
            $client.DownloadFile($Latest.URL64, $file_path)
            $global:Latest.Checksum64 = Get-FileHash $file_path -Algorithm $Algorithm | % Hash
            $global:Latest.ChecksumType32 = $Algorithm
            $global:Latest.FileName64 = $file_name
        }
    } catch{ throw $_ } finally { $client.Dispose() }
}
