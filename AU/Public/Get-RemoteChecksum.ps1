# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 26-Nov-2016.

<#
.SYNOPSIS
    Download file from internet and calculate its checksum

#>
function Get-RemoteChecksum( [string] $Url, $Algorithm='sha256', $Headers ) {
    $fn = [System.IO.Path]::GetTempFileName()
    Invoke-WebRequest $Url -OutFile $fn -UseBasicParsing -Headers $Headers
    $res = Get-FileHash $fn -Algorithm $Algorithm | ForEach-Object Hash
    Remove-Item $fn -ea ignore
    return $res.ToLower()
}

