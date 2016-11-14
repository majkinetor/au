# Returns nothing if url is valid, error otherwise
function check_url( [string] $Url, [int]$Timeout, $ExcludeType='text/html' ) {
    if (!(is_url $Url)) { return "URL syntax is invalid" }

    try
    {
        $response = request $url $Timeout
        if ($response.ContentType -like "*${ExcludeType}*") { return "Bad content type '$ExcludeType'" }
    }
    catch {
        return "Can't validate URL`n$_"
    }
}
