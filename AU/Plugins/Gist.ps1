param(
    $Info,

    # Gist id, leave empty to create a new gist
    [string] $Id,

    # Github ApiKey, create in Github profile -> Settings -> Personal access tokens -> Generate new token
    # Make sure token has 'gist' privilege.
    [string] $ApiKey,

    # File paths to attach to gist
    [string[]] $Path,

    # Gist description
    [string] $Description = "Update-AUPackages Result"
)

# Create gist
$gist = @{
    description = $Description
    public      = $true
    files       = @{}
}

ls $Path | % {
    $name      = Split-Path $_ -Leaf
    $content   = gc $_ -Raw
    $gist.files[$name] = @{content = "$content"}
}

# request
$uri  = 'https://api.github.com/gists'
$params = @{
    ContentType = 'application/json'
    Method      = if ($Id) { "PATCH" } else { "POST" }
    Uri         = if ($Id) { "$uri/$Id" } else { $uri }
    Body        = $gist | ConvertTo-Json
    UseBasicparsing = $true
}
if ($ApiKey) {
    $params.Headers = @{
        Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($ApiKey))
    }
}
$res = iwr @params

$id = Split-Path ($res.Content | ConvertFrom-Json).url -Leaf
"https://gist.github.com/$id"
