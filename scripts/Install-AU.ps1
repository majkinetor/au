<#
    Intall AU from Github using given version. Can also be used to install development branches.
    Github releases are treated as autoritative AU release source.
#>

[CmdletBinding()]
param(
    # If parsable to [version], exact AU version will be installed. Example:  '2016.10.30'
    # If not parsable to [version] it is assumed to be name of the AU git branch. Example: 'master'
    # If empty string or $null, latest release (git tag) will be installed.
    [string] $Version
)

$ErrorActionPreference = 'STOP'
$git_url = 'https://github.com/majkinetor/au.git'

if (!(gcm git -ea 0)) { throw 'Git must be installed' }
[version]$git_version = (git --version) -replace 'git|version|\.windows'
if ($git_version -lt [version]2.5) { throw 'Git version must be higher then 2.5' }

$is_branch = ![version]::TryParse($Version, [ref]($_))
$is_latest = [string]::IsNullOrWhiteSpace($Version)

$temp_dir = "$Env:TEMP\au"
mkdir -force $temp_dir | out-null
rm -recurse -force -ea 0 $temp_dir\*
pushd $temp_dir

git clone -q $git_url; cd au
git fetch --tags

if ($is_latest) { $Version = (git tag | % { [version]$_ } | sort -desc | select -first 1).ToString() }
if ($is_branch) {
    $branches = git branch | % { $_.Replace('*','').Trim() }
    if ($branches -notcontains $Version) { throw "AU branch '$Version' doesn't exist" }
} else {
    $tags = git tag
    if ($tags -notcontains $Version ) { throw "AU version '$Version' doesn't exist"}
}

git checkout -q $Version

$params = @{ Install = $true; NoChocoPackage = $true}
if (!$is_branch) { $params.Version = $Version }

"Build parameters:"
$params.GetEnumerator() | % { "  {0,-20} {1}" -f $_.Key, $_.Value }
./build.ps1 @params

popd
