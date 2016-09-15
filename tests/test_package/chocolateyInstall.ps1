$ErrorActionPreference = 'Stop'

$packageName = 'test_package'
$url32       = gcm choco.exe | % Source
$checksum32  = ''

$params = @{
  packageName  = $packageName
  fileFullPath = "$PSScriptRoot\choco.exe"
  Url          = "file:///$url32"
}
Get-ChocolateyWebFile @params
