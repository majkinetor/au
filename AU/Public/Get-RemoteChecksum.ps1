# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 14-Nov-2016.

<#
.SYNOPSIS
    Download file from internet and calculate its checksum

#>
function Get-RemoteChecksum( [string] $Url, $Algorithm='sha256' ) {
    $fn = [System.IO.Path]::GetTempFileName()
    Invoke-WebRequest $Url -OutFile $fn -UseBasicParsing
    $res = Get-FileHash $fn -Algorithm $Algorithm | % Hash
    rm $fn -ea ignore
    return $res
}

