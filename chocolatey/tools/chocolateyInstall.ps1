$ErrorActionPreference = 'Stop'

$packageName = 'au'
$url32       = 'https://github.com/majkinetor/au/archive/2016.8.15.zip'
$url64       = $url32
$checksum32  = '61812d31ca9d460eacd3b57ea61cc8830728465c10de3c2498309452118296cf'
$checksum64  = $checksum32
$toolsPath   = Split-Path $MyInvocation.MyCommand.Definition

$packageArgs = @{
  packageName    = $packageName
  url            = $url32
  url64Bit       = $url64
  checksum       = $checksum32
  checksum64     = $checksum64
  checksumType   = 'sha256'
  checksumType64 = 'sha256'
  unzipLocation  = $toolsPath
}
Install-ChocolateyZipPackage @packageArgs

$module_src = gi $toolsPath\au*
$module_dst = "$Env:ProgramFiles\WindowsPowerShell\Modules\$packageName\$Env:ChocolateyPackageVersion"
mkdir -force $module_dst | out-null
mv -force $module_src\* $module_dst
rm $module_src
