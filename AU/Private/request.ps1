function request( [string]$Url, [int]$Timeout, $Options ) {
    if ([string]::IsNullOrWhiteSpace($url)) {throw 'The URL is empty'}
    $request = [System.Net.WebRequest]::Create($Url)
    if ($Timeout)  { $request.Timeout = $Timeout*1000 }
 
    if ($Options.Headers) { 
        $Options.Headers.Keys | % { 
            if ([System.Net.WebHeaderCollection]::IsRestricted($_)) {
                $key = $_.Replace('-','')
                $request.$key = $Options.Headers[$_]
            }
            else { 
                $request.Headers.add($_, $Options.Headers[$_])
            }
        }
    }
    
    $response = $request.GetResponse()
    $response.Close()
    $response
}
