$ErrorActionPreference = 'Stop'

$toolsPath = Split-Path $MyInvocation.MyCommand.Definition
& "$toolsPath/install.ps1" -module_path $toolsPath/AU
